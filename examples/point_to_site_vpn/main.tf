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
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
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
  location = module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "this" {
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "gateway" {
  address_prefixes     = ["10.20.255.0/27"]
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

# Self-signed root certificate used for P2S certificate authentication.
resource "tls_private_key" "root" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "root" {
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]
  private_key_pem       = tls_private_key.root.private_key_pem
  validity_period_hours = 8760
  is_ca_certificate     = true

  subject {
    common_name = "P2SRootCA"
  }
}

# Public cert data must be base64 of the DER bytes (no PEM headers).
locals {
  root_cert_data = replace(replace(replace(tls_self_signed_cert.root.cert_pem,
    "-----BEGIN CERTIFICATE-----", ""),
    "-----END CERTIFICATE-----", ""),
  "\n", "")
}

# VPN gateway with Point-to-Site VPN client configuration applied directly via the root module.
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
  sku                 = "VpnGw1AZ"
  active_active       = false
  enable_telemetry    = var.enable_telemetry
  gateway_type        = "Vpn"
  vpn_client_configuration = {
    address_space            = ["172.16.201.0/24"]
    vpn_client_protocols     = ["OpenVPN"]
    vpn_authentication_types = ["Certificate"]
    root_certificates = {
      P2SRootCA = {
        public_cert_data = local.root_cert_data
      }
    }
  }
  vpn_gateway_generation = "Generation1"
  vpn_type               = "RouteBased"
}
