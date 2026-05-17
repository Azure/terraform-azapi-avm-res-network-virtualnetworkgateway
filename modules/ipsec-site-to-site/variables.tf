variable "connection_name" {
  type        = string
  description = "The name of the IPsec virtual network gateway connection."
  nullable    = false
}

variable "local_network_gateway" {
  type = object({
    name               = string
    address_space      = list(string)
    gateway_ip_address = optional(string, null)
    fqdn               = optional(string, null)
    bgp_settings = optional(object({
      asn                 = optional(number, null)
      bgp_peering_address = optional(string, null)
      peer_weight         = optional(number, null)
    }), null)
  })
  description = <<DESCRIPTION
Local network gateway definition representing the on-premises VPN device.

- `name` - The name of the local network gateway.
- `address_space` - List of CIDR blocks describing the on-premises network.
- `gateway_ip_address` - (Optional) Public IPv4 of the on-premises device. One of `gateway_ip_address` or `fqdn` must be provided.
- `fqdn` - (Optional) FQDN of the on-premises device.
- `bgp_settings` - (Optional) BGP settings for the local network gateway.
DESCRIPTION
  nullable    = false

  validation {
    condition     = var.local_network_gateway.gateway_ip_address != null || var.local_network_gateway.fqdn != null
    error_message = "Either `gateway_ip_address` or `fqdn` must be provided on the local network gateway."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the local network gateway and connection."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "The resource group name where the local network gateway and connection are deployed."
  nullable    = false
}

variable "shared_key" {
  type        = string
  description = "The IPsec shared key (PSK) used to authenticate the tunnel."
  nullable    = false
  sensitive   = true
}

variable "virtual_network_gateway_resource_id" {
  type        = string
  description = "The resource ID of the virtual network gateway acting as the Azure side of the IPsec tunnel."
  nullable    = false
}

variable "connection_mode" {
  type        = string
  default     = null
  description = "Connection mode. Possible values are `Default`, `ResponderOnly`, and `InitiatorOnly`."

  validation {
    condition     = var.connection_mode == null || contains(["Default", "ResponderOnly", "InitiatorOnly"], coalesce(var.connection_mode, "Default"))
    error_message = "`connection_mode` must be `Default`, `ResponderOnly`, or `InitiatorOnly`."
  }
}

variable "connection_protocol" {
  type        = string
  default     = null
  description = "The IKE protocol version. Possible values are `IKEv1` and `IKEv2`."

  validation {
    condition     = var.connection_protocol == null || contains(["IKEv1", "IKEv2"], coalesce(var.connection_protocol, "IKEv2"))
    error_message = "`connection_protocol` must be `IKEv1` or `IKEv2`."
  }
}

variable "dpd_timeout_seconds" {
  type        = number
  default     = null
  description = "The dead peer detection timeout in seconds."
}

variable "egress_nat_rule_resource_ids" {
  type        = list(string)
  default     = []
  description = "List of NAT rule resource IDs to apply as egress rules on this connection."
  nullable    = false
}

variable "enable_bgp" {
  type        = bool
  default     = false
  description = "Whether BGP is enabled for this connection."
  nullable    = false
}

variable "express_route_gateway_bypass" {
  type        = bool
  default     = false
  description = "Bypass ExpressRoute Gateway for data forwarding."
  nullable    = false
}

variable "gateway_custom_bgp_ip_addresses" {
  type = list(object({
    ip_configuration_name = string
    custom_bgp_ip_address = string
  }))
  default     = null
  description = <<DESCRIPTION
Per-connection mapping of the Azure-side custom BGP IP addresses (APIPA) to the gateway IP configurations. Required when the parent virtual network gateway is configured with `custom_ips` in its BGP peering addresses, so that this specific tunnel knows which APIPA IP to use for BGP peering.

- `ip_configuration_name` - The name of the gateway IP configuration this entry applies to (must match a key/name in the gateway's `ip_configurations`).
- `custom_bgp_ip_address` - The APIPA IP from the gateway's `bgp_settings.peering_addresses.<key>.custom_ips` list to use on this connection.
DESCRIPTION
}

variable "inbound_certificate_chain" {
  type        = list(string)
  default     = null
  description = "Public certificate(s) of the peer used to validate inbound authentication on the IPsec connection. Each entry must be the base64-encoded DER of the certificate (i.e. the contents of a PEM file without the `-----BEGIN/END CERTIFICATE-----` lines), matching the format Azure VPN gateway uses for root certificates."
}

variable "inbound_certificate_subject_name" {
  type        = string
  default     = null
  description = "Distinguished/Subject Name (e.g. `CN=peer-ipsec`) that the peer's certificate must present for inbound authentication on the IPsec connection."
}

variable "ingress_nat_rule_resource_ids" {
  type        = list(string)
  default     = []
  description = "List of NAT rule resource IDs to apply as ingress rules on this connection."
  nullable    = false
}

variable "ipsec_policies" {
  type = list(object({
    sa_lifetime_seconds    = number
    sa_data_size_kilobytes = number
    ipsec_encryption       = string
    ipsec_integrity        = string
    ike_encryption         = string
    ike_integrity          = string
    dh_group               = string
    pfs_group              = string
  }))
  default     = null
  description = <<DESCRIPTION
Custom IPsec/IKE policies for the connection. When set, overrides the default policy.

Each entry requires the following fields with values from the supported policy combinations: `sa_lifetime_seconds`, `sa_data_size_kilobytes`, `ipsec_encryption`, `ipsec_integrity`, `ike_encryption`, `ike_integrity`, `dh_group`, `pfs_group`.
DESCRIPTION
}

variable "outbound_certificate_path" {
  type        = string
  default     = null
  description = "Key Vault **certificate** URI (e.g. `https://<vault>.vault.azure.net/certificates/<name>` or `.../certificates/<name>/<version>`) for the certificate used by this gateway to authenticate outbound on the IPsec connection. The URI must point to a `certificates/` object, not a `secrets/` object. Requires the gateway to have a managed identity with access to the Key Vault."
}

variable "routing_weight" {
  type        = number
  default     = null
  description = "The routing weight for the connection."
}

variable "shared_key_version" {
  type        = string
  default     = "1"
  description = "Increment this when rotating `shared_key` to force AzAPI to send the updated value."
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags to apply to the local network gateway and connection."
}

variable "traffic_selector_policies" {
  type = list(object({
    local_address_ranges  = list(string)
    remote_address_ranges = list(string)
  }))
  default     = null
  description = "Traffic selector policies (used when `use_policy_based_traffic_selectors` is `true`)."
}

variable "use_policy_based_traffic_selectors" {
  type        = bool
  default     = false
  description = "Whether to enable policy-based traffic selectors. Requires `traffic_selector_policies` to be set."
  nullable    = false
}
