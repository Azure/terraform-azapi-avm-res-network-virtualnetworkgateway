variable "express_route_circuit_resource_id" {
  type        = string
  description = "The resource ID of the ExpressRoute circuit to connect the gateway to."
  nullable    = false
}

variable "location" {
  type        = string
  description = "Azure region for the connection resource."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the ExpressRoute connection (`Microsoft.Network/connections`)."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "The resource group where the connection resource is deployed. Typically the same resource group as the virtual network gateway."
  nullable    = false
}

variable "virtual_network_gateway_resource_id" {
  type        = string
  description = "The resource ID of the ExpressRoute virtual network gateway (gatewayType = `ExpressRoute`)."
  nullable    = false
}

variable "authorization_key" {
  type        = string
  default     = null
  description = "The authorization key used to authorize the connection. Required when connecting to a circuit in a different subscription/tenant."
  sensitive   = true
}

variable "authorization_key_version" {
  type        = string
  default     = "1"
  description = "Increment to force re-deployment of `authorization_key`."
  nullable    = false
}

variable "enable_private_link_fast_path" {
  type        = bool
  default     = false
  description = "Whether to enable Private Link FastPath on the connection. Requires `express_route_gateway_bypass` to be `true` and a supported gateway SKU."
  nullable    = false
}

variable "express_route_gateway_bypass" {
  type        = bool
  default     = false
  description = "Whether to bypass the ExpressRoute gateway for data forwarding (FastPath)."
  nullable    = false
}

variable "routing_weight" {
  type        = number
  default     = null
  description = "The routing weight for the connection."
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags applied to the connection resource."
}
