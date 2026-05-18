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
  location = "italynorth" #module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# Random shared key (PSK) used by both IPsec connections.
resource "random_password" "psk" {
  length  = 32
  special = false
}

#############################################
# Cloud side (Azure VNet acting as "Azure") #
#############################################

resource "azurerm_virtual_network" "cloud_vnet" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.40.0.0/16"]
}

resource "azurerm_subnet" "cloud_gateway_subnet" {
  address_prefixes     = ["10.40.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.cloud_vnet.name
}

resource "azurerm_public_ip" "cloud_pip" {
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

####################################################
# On-prem side (Azure VNet simulating on-premises) #
####################################################

resource "azurerm_virtual_network" "onprem_vnet" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.50.0.0/16"]
}

resource "azurerm_subnet" "onprem_gateway_subnet" {
  address_prefixes     = ["10.50.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.onprem_vnet.name
}

resource "azurerm_public_ip" "onprem_pip" {
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
############################################
# BGP peer IPs and ASNs
#
# Both gateways use the default (subnet-derived) BGP peer IP address from
# their respective GatewaySubnet. To avoid the chicken-and-egg dependency
# that would otherwise exist between the two gateway modules (each module
# would need to reference the other's computed `bgp_peering_address`), the
# default BGP peer IPs are hard-coded here. These addresses are stable for
# this deployment and will not change between subsequent applies.
############################################

locals {
  cloud_asn          = 65050
  cloud_bgp_peer_ip  = "10.40.255.30"
  onprem_asn         = 65051
  onprem_bgp_peer_ip = "10.50.255.30"
}

# "Cloud" VPN gateway with BGP enabled. The IPsec + BGP connection towards the
# on-prem side is created via the gateway module's
# `ipsec_site_to_site_connections` input.
module "cloud" {
  source = "../../"

  ip_configurations = {
    primary = {
      name                          = "primary"
      subnet_resource_id            = azurerm_subnet.cloud_gateway_subnet.id
      public_ip_address_resource_id = azurerm_public_ip.cloud_pip.id
    }
  }
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network_gateway.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw1AZ"
  active_active       = false
  bgp_settings = {
    asn         = local.cloud_asn
    peer_weight = 0
    peering_addresses = {
      primary = {
        ip_configuration_name = "primary"
      }
    }
  }
  enable_bgp       = true
  enable_telemetry = var.enable_telemetry
  gateway_type     = "Vpn"
  ipsec_site_to_site_connections = {
    to-onprem = {
      connection_name     = "${module.naming.virtual_network_gateway.name_unique}-cloud-to-onprem"
      shared_key          = random_password.psk.result
      enable_bgp          = true
      connection_protocol = "IKEv2"
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-onprem"
        address_space      = ["${local.onprem_bgp_peer_ip}/32"]
        gateway_ip_address = azurerm_public_ip.onprem_pip.ip_address
        bgp_settings = {
          asn                 = local.onprem_asn
          bgp_peering_address = local.onprem_bgp_peer_ip
          peer_weight         = 0
        }
      }
      tags = {
        scenario  = "bgp"
        direction = "cloud-to-onprem"
      }
    }
  }
  tags = {
    scenario = "bgp"
    side     = "cloud"
  }
  vpn_type = "RouteBased"
}

# "On-prem" VPN gateway with BGP enabled. Distinct private ASN from the cloud side.
module "onprem" {
  source = "../../"

  ip_configurations = {
    primary = {
      name                          = "primary"
      subnet_resource_id            = azurerm_subnet.onprem_gateway_subnet.id
      public_ip_address_resource_id = azurerm_public_ip.onprem_pip.id
    }
  }
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network_gateway.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw1AZ"
  bgp_settings = {
    asn         = local.onprem_asn
    peer_weight = 0
    peering_addresses = {
      primary = {
        ip_configuration_name = "primary"
      }
    }
  }
  enable_bgp       = true
  enable_telemetry = var.enable_telemetry
  gateway_type     = "Vpn"
  ipsec_site_to_site_connections = {
    to-cloud = {
      connection_name     = "${module.naming.virtual_network_gateway.name_unique}-onprem-to-cloud"
      shared_key          = random_password.psk.result
      enable_bgp          = true
      connection_protocol = "IKEv2"
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-cloud"
        address_space      = ["${local.cloud_bgp_peer_ip}/32"]
        gateway_ip_address = azurerm_public_ip.cloud_pip.ip_address
        bgp_settings = {
          asn                 = local.cloud_asn
          bgp_peering_address = local.cloud_bgp_peer_ip
          peer_weight         = 0
        }
      }
      tags = {
        scenario  = "bgp"
        direction = "onprem-to-cloud"
      }
    }
  }
  tags = {
    scenario = "bgp"
    side     = "onprem"
  }
  vpn_type = "RouteBased"
}
