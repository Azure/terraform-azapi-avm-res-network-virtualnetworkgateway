terraform {
  required_version = "~> 1.9"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {}
}

data "azurerm_client_config" "current" {}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "0.12.0"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.4.3"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# ---------------------------------------------------------------------------
# Two virtual networks with *mostly overlapping* address space.
#
# Both VNets advertise the same /16 (10.10.0.0/16), which is a very common
# real-world problem when connecting two sites that were provisioned
# independently. Only a small slice differs: each side carves a unique
# /24 workload subnet out of the shared /16:
#
#   cloud  workload : 10.10.1.0/24
#   onprem workload : 10.10.2.0/24
#
# Because the parent /16s collide, the gateways cannot route the raw
# internal address spaces over the IPsec tunnel. NAT rules below translate
# each side's workload /24 into a non-overlapping "external" /24 so the
# remote side has a unique destination prefix to route to.
# ---------------------------------------------------------------------------
locals {
  cloud_egress_nat_rule_id = "${local.gateway_id_prefix}/${local.cloud_gateway_name}/natRules/egress-workload"
  # External (translated) representation each side advertises to the peer.
  cloud_external_cidr = "10.100.1.0/24"
  # Gateway names are computed once so they can be referenced both as inputs
  # to the root module and used to construct predictable NAT rule resource
  # IDs that the IPsec connections (declared in the same module call) refer
  # back to via `ingress_nat_rule_resource_ids` / `egress_nat_rule_resource_ids`.
  cloud_gateway_name = "${module.naming.virtual_network_gateway.name_unique}-cloud"
  # Internal (real) workload subnets - small non-overlapping slices of the
  # otherwise identical /16.
  cloud_workload_cidr       = "10.10.1.0/24"
  gateway_id_prefix         = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.this.name}/providers/Microsoft.Network/virtualNetworkGateways"
  onprem_gateway_name       = "${module.naming.virtual_network_gateway.name_unique}-onprem"
  onprem_workload_cidr      = "10.11.0.0/24"
  overlapping_address_space = "10.10.0.0/16"
}

# --- Cloud-side VNet ---------------------------------------------------------
resource "azurerm_virtual_network" "cloud" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [local.overlapping_address_space]
}

resource "azurerm_subnet" "cloud_workload" {
  address_prefixes     = [local.cloud_workload_cidr]
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.cloud.name
}

resource "azurerm_subnet" "cloud_gateway" {
  address_prefixes     = ["10.10.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.cloud.name
}

resource "azurerm_public_ip" "cloud" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.public_ip.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [ip_tags, tags]
  }
}

# --- Onprem-side VNet (stand-in for an on-premises datacenter) ---------------
resource "azurerm_virtual_network" "onprem" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = [local.overlapping_address_space, "10.11.0.0/16"]
}

resource "azurerm_subnet" "onprem_workload" {
  address_prefixes     = [local.onprem_workload_cidr]
  name                 = "workload"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem.name
}

resource "azurerm_subnet" "onprem_gateway" {
  address_prefixes     = ["10.10.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem.name
}

resource "azurerm_public_ip" "onprem" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.public_ip.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [ip_tags, tags]
  }
}

# Random pre-shared key for the IPsec tunnel (used by both sides).
resource "random_password" "ipsec_psk" {
  length           = 48
  override_special = "_-.~"
  special          = true
}

# ---------------------------------------------------------------------------
# Cloud-side virtual network gateway.
#
# NAT rules are declared directly on the root module via `var.nat_rules`;
# the module internally calls the `nat-rules` submodule. The IPsec
# connection references the NAT rules by predicted resource ID so the
# rules are applied to traffic on this specific tunnel.
#
# The local network gateway advertises the *external* (post-NAT) onprem
# range - never the overlapping internal /16 - so the cloud-side routing
# table has a unique destination prefix.
# ---------------------------------------------------------------------------
module "cloud" {
  source = "../../"

  ip_configurations = {
    primary = {
      subnet_resource_id            = azurerm_subnet.cloud_gateway.id
      public_ip_address_resource_id = azurerm_public_ip.cloud.id
    }
  }
  location            = azurerm_resource_group.this.location
  name                = local.cloud_gateway_name
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw2AZ"
  active_active       = false
  enable_telemetry    = var.enable_telemetry
  gateway_type        = "Vpn"
  ipsec_site_to_site_connections = {
    cloud-to-onprem = {
      connection_name = "cloud-to-onprem"
      shared_key      = random_password.ipsec_psk.result
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-onprem"
        address_space      = ["10.11.0.0/16"]
        gateway_ip_address = azurerm_public_ip.onprem.ip_address
      }
      connection_protocol          = "IKEv2"
      egress_nat_rule_resource_ids = [local.cloud_egress_nat_rule_id]
    }
  }
  nat_rules = {
    # Egress SNAT: rewrite the cloud workload /24 to a unique external /24
    # before packets leave over the tunnel.
    egress_workload = {
      name = "egress-workload"
      mode = "EgressSnat"
      internal_mappings = [
        { address_space = local.cloud_workload_cidr }
      ]
      external_mappings = [
        { address_space = local.cloud_external_cidr }
      ]
    }
  }
  tags = {
    scenario = "nat-rules"
    role     = "cloud"
  }
  vpn_type = "RouteBased"
}

# ---------------------------------------------------------------------------
# Onprem-side virtual network gateway with the mirror-image NAT rules.
# ---------------------------------------------------------------------------
module "onprem" {
  source = "../../"

  ip_configurations = {
    primary = {
      subnet_resource_id            = azurerm_subnet.onprem_gateway.id
      public_ip_address_resource_id = azurerm_public_ip.onprem.id
    }
  }
  location            = azurerm_resource_group.this.location
  name                = local.onprem_gateway_name
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw2AZ"
  active_active       = false
  enable_telemetry    = var.enable_telemetry
  gateway_type        = "Vpn"
  ipsec_site_to_site_connections = {
    onprem-to-cloud = {
      connection_name = "onprem-to-cloud"
      shared_key      = random_password.ipsec_psk.result
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-cloud"
        address_space      = [local.cloud_external_cidr]
        gateway_ip_address = azurerm_public_ip.cloud.ip_address
      }
      connection_protocol = "IKEv2"
    }
  }
  tags = {
    scenario = "nat-rules"
    role     = "onprem"
  }
  vpn_type = "RouteBased"
}
