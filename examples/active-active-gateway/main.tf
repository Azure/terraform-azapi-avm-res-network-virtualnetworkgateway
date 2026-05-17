terraform {
  required_version = "~> 1.9"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.9"
    }
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

# Provide a random Azure region for the resource group.
module "regions" {
  source  = "Azure/avm-utl-regions/azurerm"
  version = "~> 0.1"
}

resource "random_integer" "region_index" {
  max = length(module.regions.regions) - 1
  min = 0
}

# Unique CAF compliant names for resources.
module "naming" {
  source  = "Azure/naming/azurerm"
  version = "~> 0.3"
}

resource "azurerm_resource_group" "this" {
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  address_prefixes     = ["10.0.255.0/27"]
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
}

# Active-active gateways require two public IP addresses, one per IP configuration.
resource "azurerm_public_ip" "primary" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.public_ip.name_unique}-primary"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

resource "azurerm_public_ip" "secondary" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.public_ip.name_unique}-secondary"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Module call.
module "test" {
  source = "../../"

  ip_configurations = {
    primary = {
      name                          = "primary"
      subnet_resource_id            = azurerm_subnet.gateway.id
      public_ip_address_resource_id = azurerm_public_ip.primary.id
    }
    secondary = {
      name                          = "secondary"
      subnet_resource_id            = azurerm_subnet.gateway.id
      public_ip_address_resource_id = azurerm_public_ip.secondary.id
    }
  }
  location                  = azurerm_resource_group.this.location
  name                      = module.naming.virtual_network_gateway.name_unique
  resource_group_name       = azurerm_resource_group.this.name
  sku                       = "VpnGw2AZ"
  active_active             = true
  enable_private_ip_address = true
  enable_telemetry          = var.enable_telemetry
  gateway_type              = "Vpn"
  vpn_type                  = "RouteBased"
}
