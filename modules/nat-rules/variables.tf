variable "nat_rules" {
  type = map(object({
    name                = optional(string, null)
    type                = optional(string, "Static")
    mode                = string
    ip_configuration_id = optional(string, null)
    internal_mappings = list(object({
      address_space = string
      port_range    = optional(string, null)
    }))
    external_mappings = list(object({
      address_space = string
      port_range    = optional(string, null)
    }))
  }))
  description = <<DESCRIPTION
A map of NAT rules to create on the virtual network gateway. Map keys are arbitrary.

- `name` - (Optional) The NAT rule name. Defaults to the map key.
- `type` - (Optional) The NAT rule type. Possible values are `Static` and `Dynamic`. Defaults to `Static`.
- `mode` - (Required) The NAT direction. Possible values are `EgressSnat` and `IngressSnat`.
- `ip_configuration_id` - (Optional) The ID of the gateway IP configuration this rule applies to.
- `internal_mappings` - List of internal address mappings.
  - `address_space` - The internal address space in CIDR notation.
  - `port_range` - (Optional) The port range (e.g. `100-200`).
- `external_mappings` - List of external address mappings.
  - `address_space` - The external address space in CIDR notation.
  - `port_range` - (Optional) The port range (e.g. `100-200`).
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.nat_rules : contains(["Static", "Dynamic"], v.type)])
    error_message = "`type` must be either `Static` or `Dynamic`."
  }
  validation {
    condition     = alltrue([for _, v in var.nat_rules : contains(["EgressSnat", "IngressSnat"], v.mode)])
    error_message = "`mode` must be either `EgressSnat` or `IngressSnat`."
  }
}

variable "virtual_network_gateway_resource_id" {
  type        = string
  description = "The resource ID of the parent virtual network gateway."
  nullable    = false
}
