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

locals {
  bandwidth_in_gbps = 10
  encapsulation     = "Dot1Q"
  erd_port_name     = "office1"
  family            = "MeteredData"
  peering_location  = "Equinix-Amsterdam-AM5"
  tier              = "Premium"
}

module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.12.0"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.4.3"
}

resource "azurerm_resource_group" "this" {
  location = "italynorth"
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.30.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  address_prefixes     = ["10.30.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

resource "azurerm_public_ip" "this" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]

  lifecycle {
    ignore_changes = [ip_tags, tags]
  }
}

# ExpressRoute Direct port. This represents the physical port pair purchased
# from Microsoft. `admin_enabled = false` keeps the links disabled so no
# billing is incurred for the underlying physical links while still allowing
# the port (and a child circuit) to be provisioned end-to-end.
resource "azurerm_express_route_port" "this" {
  bandwidth_in_gbps   = local.bandwidth_in_gbps
  encapsulation       = local.encapsulation
  location            = azurerm_resource_group.this.location
  name                = "erd-${local.erd_port_name}"
  peering_location    = local.peering_location
  resource_group_name = azurerm_resource_group.this.name

  link1 {
    admin_enabled = false
    macsec_cipher = "GcmAes256"
  }
  link2 {
    admin_enabled = false
    macsec_cipher = "GcmAes256"
  }
}

# ExpressRoute circuit backed by the ExpressRoute Direct port above. Built
# using the AVM ExpressRoute circuit resource module.
module "expressroute_circuit" {
  source  = "Azure/avm-res-network-expressroutecircuit/azurerm"
  version = "~> 0.3.3"

  location            = azurerm_resource_group.this.location
  name                = module.naming.express_route_circuit.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku = {
    tier   = local.tier
    family = local.family
  }
  bandwidth_in_gbps              = local.bandwidth_in_gbps
  enable_telemetry               = var.enable_telemetry
  express_route_port_resource_id = azurerm_express_route_port.this.id
  # AzurePrivatePeering must be provisioned on the circuit before the
  # ExpressRoute virtual network gateway connection can be created, otherwise
  # the connection deployment fails with "BGP peering with service key '...'
  # could not be found.".
  peerings = {
    PrivatePeering = {
      peering_type                  = "AzurePrivatePeering"
      peer_asn                      = 65001
      primary_peer_address_prefix   = "10.99.0.0/30"
      secondary_peer_address_prefix = "10.99.0.4/30"
      ipv4_enabled                  = true
      vlan_id                       = 300
    }
  }
}

# ExpressRoute virtual network gateway. The `expressroute_connections` map
# wires the gateway to the ExpressRoute circuit created above, producing a
# `Microsoft.Network/connections` resource of type `ExpressRoute`.
module "test" {
  source = "../../"

  ip_configurations = {
    primary = {
      subnet_resource_id            = azurerm_subnet.gateway.id
      public_ip_address_resource_id = azurerm_public_ip.this.id
    }
  }
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network_gateway.name_unique
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "ErGw1AZ"
  enable_telemetry    = var.enable_telemetry
  expressroute_connections = {
    primary = {
      express_route_circuit_resource_id = module.expressroute_circuit.resource_id
    }
  }
  gateway_type = "ExpressRoute"
  tags = {
    scenario = "expressroute"
  }
  # ExpressRoute gateways must use vpn_gateway_generation = "None".
  vpn_gateway_generation = "None"
}
