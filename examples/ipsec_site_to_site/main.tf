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
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
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
  location = "italynorth" #module.regions.regions[random_integer.region_index.result].name
  name     = module.naming.resource_group.name_unique
}

# ---------------------------------------------------------------------------
# "Cloud" virtual network and gateway subnet (Azure-side workload network).
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "cloud" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.10.0.0/16"]
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

# ---------------------------------------------------------------------------
# "On-prem" virtual network and gateway subnet. A second Azure VNet stands in
# for an on-premises datacenter so the IPsec tunnel can be fully exercised
# end-to-end inside a single example.
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "onprem" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.virtual_network.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
}

resource "azurerm_subnet" "onprem_gateway" {
  address_prefixes     = ["10.20.255.0/27"]
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

# ---------------------------------------------------------------------------
# User assigned managed identity that both gateways are attached to. In this
# example the IPsec authentication key is also retrievable by the gateways
# from Key Vault via this identity (handy if you later switch to fetching
# the PSK at runtime instead of passing it through Terraform state).
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "gateway" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.user_assigned_identity.name_unique}-vng"
  resource_group_name = azurerm_resource_group.this.name
}

# ---------------------------------------------------------------------------
# Key Vault with RBAC authorization that stores the IPsec authentication
# key (pre-shared key) generated below.
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "this" {
  location                   = azurerm_resource_group.this.location
  name                       = module.naming.key_vault.name_unique
  resource_group_name        = azurerm_resource_group.this.name
  sku_name                   = "standard"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
}

# The Terraform principal needs permission to write the authentication key
# secret into the Key Vault.
resource "azurerm_role_assignment" "current_kv_secrets_officer" {
  principal_id         = data.azurerm_client_config.current.object_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
}

# Grant the gateway's user assigned identity read access to secrets so the
# stored authentication key can be retrieved by the gateways.
resource "azurerm_role_assignment" "uami_kv_secrets_user" {
  principal_id         = azurerm_user_assigned_identity.gateway.principal_id
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
}

# Give the role assignments a moment to propagate before writing the secret,
# which requires data-plane permissions.
resource "time_sleep" "role_propagation" {
  create_duration = "60s"

  depends_on = [
    azurerm_role_assignment.current_kv_secrets_officer,
    azurerm_role_assignment.uami_kv_secrets_user,
  ]
}

# Random authentication key (pre-shared key) for the IPsec tunnel. Stored
# in Key Vault so it has a single source of truth that can be rotated by
# updating the secret value (and bumping `shared_key_version` on the
# connections to force AzAPI to re-send the PSK).
resource "random_password" "ipsec_auth_key" {
  length           = 64
  override_special = "_-.~"
  special          = true
}

resource "azurerm_key_vault_secret" "ipsec_auth_key" {
  key_vault_id = azurerm_key_vault.this.id
  name         = "ipsec-auth-key"
  content_type = "text/plain"
  value        = random_password.ipsec_auth_key.result

  depends_on = [time_sleep.role_propagation]
}

# The IPsec connection authenticates with this pre-shared key. Both sides
# read the same value from Key Vault so the IKEv2 handshake succeeds.
locals {
  ipsec_shared_key = azurerm_key_vault_secret.ipsec_auth_key.value
}

# ---------------------------------------------------------------------------
# Cloud-side virtual network gateway with the user assigned identity attached
# so it can access the Key Vault.
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
  name                = "${module.naming.virtual_network_gateway.name_unique}-cloud"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw1AZ"
  enable_telemetry    = var.enable_telemetry
  gateway_type        = "Vpn"
  ipsec_site_to_site_connections = {
    cloud-to-onprem = {
      connection_name = "cloud-to-onprem"
      # Authentication key (pre-shared key) sourced from Key Vault.
      shared_key = local.ipsec_shared_key
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-onprem"
        address_space      = azurerm_virtual_network.onprem.address_space
        gateway_ip_address = azurerm_public_ip.onprem.ip_address
      }
      connection_protocol = "IKEv2"
      dpd_timeout_seconds = 45
      tags = {
        scenario  = "ipsec-site-to-site"
        direction = "cloud-to-onprem"
      }
    }
  }
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.gateway.id]
  }
  tags = {
    scenario = "ipsec-site-to-site"
    role     = "cloud"
  }
  vpn_type = "RouteBased"
}

# ---------------------------------------------------------------------------
# On-prem-side virtual network gateway, also attached to the same user
# assigned identity for Key Vault access.
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
  name                = "${module.naming.virtual_network_gateway.name_unique}-onprem"
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "VpnGw1AZ"
  enable_telemetry    = var.enable_telemetry
  gateway_type        = "Vpn"
  ipsec_site_to_site_connections = {
    onprem-to-cloud = {
      connection_name = "onprem-to-cloud"
      # Authentication key (pre-shared key) sourced from Key Vault.
      shared_key = local.ipsec_shared_key
      local_network_gateway = {
        name               = "${module.naming.local_network_gateway.name_unique}-cloud"
        address_space      = azurerm_virtual_network.cloud.address_space
        gateway_ip_address = azurerm_public_ip.cloud.ip_address
      }
      connection_protocol = "IKEv2"
      dpd_timeout_seconds = 45
      tags = {
        scenario  = "ipsec-site-to-site"
        direction = "onprem-to-cloud"
      }
    }
  }
  managed_identities = {
    user_assigned_resource_ids = [azurerm_user_assigned_identity.gateway.id]
  }
  tags = {
    scenario = "ipsec-site-to-site"
    role     = "onprem"
  }
  vpn_type = "RouteBased"
}
