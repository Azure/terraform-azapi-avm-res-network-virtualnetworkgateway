data "azapi_client_config" "current" {}

locals {
  resource_group_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

# Customer-controlled maintenance configuration for a virtual network gateway.
# Uses `maintenanceScope = "Resource"` together with the
# `NetworkGatewayMaintenance` sub-scope, which is the public scope Azure
# accepts for VPN / ExpressRoute gateway maintenance windows.
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.Maintenance/maintenanceConfigurations@2023-04-01"
  body = {
    properties = {
      maintenanceScope = "Resource"
      extensionProperties = {
        maintenanceSubScope = "NetworkGatewayMaintenance"
      }
      maintenanceWindow = {
        startDateTime = var.maintenance_window.start_date_time
        duration      = var.maintenance_window.duration
        timeZone      = var.maintenance_window.time_zone
        recurEvery    = var.maintenance_window.recur_every
      }
    }
  }
  # Azure normalizes the resource ID casing in responses (e.g.
  # `resourcegroups` / `microsoft.maintenance`). Compare bodies
  # case-insensitively so the server-side normalization does not cause
  # persistent drift.
  ignore_casing = true
  response_export_values = [
    "id",
    "name",
  ]
  tags = var.tags
}

# Bind the maintenance configuration to the virtual network gateway so the
# window actually applies to the gateway.
resource "azapi_resource" "assignment" {
  location  = var.location
  name      = coalesce(var.assignment_name, var.name)
  parent_id = var.virtual_network_gateway_resource_id
  type      = "Microsoft.Maintenance/configurationAssignments@2023-04-01"
  body = {
    properties = {
      maintenanceConfigurationId = azapi_resource.this.id
    }
  }
  # Azure lowercases segments of `maintenanceConfigurationId` in responses
  # (`resourcegroups`, `microsoft.maintenance/maintenanceconfigurations`).
  # Without this, every plan reports a no-op update to restore the casing.
  ignore_casing = true
  response_export_values = [
    "id",
    "name",
  ]
}
