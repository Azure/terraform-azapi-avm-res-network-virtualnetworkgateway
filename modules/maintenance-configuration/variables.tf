variable "location" {
  type        = string
  description = "Azure region for the maintenance configuration."
  nullable    = false
}

variable "maintenance_window" {
  type = object({
    start_date_time = string
    duration        = string
    time_zone       = optional(string, "UTC")
    recur_every     = string
  })
  description = <<DESCRIPTION
The maintenance window definition.

- `start_date_time` - The window anchor in `YYYY-MM-DD HH:MM` format. Only anchors the recurrence; the actual cadence is driven by `recur_every`.
- `duration` - Window length as `HH:MM`. Azure currently enforces a minimum of 5 hours (`"05:00"`) for the `NetworkGatewayMaintenance` sub-scope.
- `time_zone` - (Optional) IANA / Windows time zone identifier. Defaults to `UTC`.
- `recur_every` - Recurrence expression accepted by the Maintenance API, e.g. `"1Day"`, `"Week Saturday"`, `"Week Saturday,Sunday"`.
DESCRIPTION
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the maintenance configuration (`Microsoft.Maintenance/maintenanceConfigurations`)."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "The resource group where the maintenance configuration is deployed."
  nullable    = false
}

variable "virtual_network_gateway_resource_id" {
  type        = string
  description = "The resource ID of the virtual network gateway to assign this maintenance configuration to."
  nullable    = false
}

variable "assignment_name" {
  type        = string
  default     = null
  description = "(Optional) The name of the `configurationAssignments` child resource created under the gateway. Defaults to the maintenance configuration `name`."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags applied to the maintenance configuration."
}
