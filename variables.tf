variable "ip_configurations" {
  type = map(object({
    name                          = optional(string, null)
    subnet_resource_id            = string
    public_ip_address_resource_id = optional(string, null)
    private_ip_allocation_method  = optional(string, "Dynamic")
  }))
  description = <<DESCRIPTION
A map of IP configurations to create on the virtual network gateway. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

At least one IP configuration is required. Active-active VPN gateways require two; ExpressRoute and active-active VPN gateways using BGP commonly require additional configurations.

- `name` - (Optional) The name of the IP configuration. Defaults to the map key.
- `subnet_resource_id` - (Required) The resource ID of the `GatewaySubnet` to associate with the gateway.
- `public_ip_address_resource_id` - (Optional) The resource ID of the public IP address to associate with this IP configuration. Required for non-private gateways.
- `private_ip_allocation_method` - (Optional) The private IP allocation method. Possible values are `Static` and `Dynamic`. Defaults to `Dynamic`.
DESCRIPTION
  nullable    = false

  validation {
    condition     = length(var.ip_configurations) >= 1
    error_message = "At least one IP configuration is required for a virtual network gateway."
  }
  validation {
    condition     = alltrue([for _, v in var.ip_configurations : contains(["Static", "Dynamic"], v.private_ip_allocation_method)])
    error_message = "`private_ip_allocation_method` must be one of `Static` or `Dynamic`."
  }
}

variable "location" {
  type        = string
  description = "Azure region where the virtual network gateway should be deployed."
  nullable    = false
}

variable "name" {
  type        = string
  description = "The name of the virtual network gateway."

  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9._-]{0,78}[a-zA-Z0-9_]$", var.name))
    error_message = "The virtual network gateway name must be 1-80 characters long, start with an alphanumeric, end with alphanumeric or underscore, and may only contain alphanumerics, underscores, periods, and hyphens."
  }
}

variable "resource_group_name" {
  type        = string
  description = "The name of the resource group where the virtual network gateway will be deployed."
  nullable    = false
}

variable "sku" {
  type        = string
  description = <<DESCRIPTION
The SKU of the virtual network gateway. Used as both the SKU `name` and `tier`.

Common values:
- VPN: `VpnGw1`, `VpnGw2`, `VpnGw3`, `VpnGw4`, `VpnGw5`, `VpnGw1AZ`, `VpnGw2AZ`, `VpnGw3AZ`, `VpnGw4AZ`, `VpnGw5AZ`
- ExpressRoute: `Standard`, `HighPerformance`, `UltraPerformance`, `ErGw1AZ`, `ErGw2AZ`, `ErGw3AZ`, `ErGwScale`
DESCRIPTION
  nullable    = false

  validation {
    condition = contains([
      "Basic", "Standard", "HighPerformance", "UltraPerformance",
      "VpnGw1", "VpnGw2", "VpnGw3", "VpnGw4", "VpnGw5",
      "VpnGw1AZ", "VpnGw2AZ", "VpnGw3AZ", "VpnGw4AZ", "VpnGw5AZ",
      "ErGw1AZ", "ErGw2AZ", "ErGw3AZ", "ErGwScale",
    ], var.sku)
    error_message = "Invalid SKU. See documentation for the list of supported SKUs."
  }
}

variable "active_active" {
  type        = bool
  default     = false
  description = "Whether to deploy the gateway in active-active mode. Requires at least 2 IP configurations."
  nullable    = false
}

variable "bgp_settings" {
  type = object({
    asn         = optional(number, null)
    peer_weight = optional(number, null)
    peering_addresses = optional(map(object({
      ip_configuration_name = string
      custom_ips            = optional(list(string), null)
    })), {})
  })
  default     = null
  description = <<DESCRIPTION
BGP speaker settings for the virtual network gateway.

- `asn` - (Optional) The autonomous system number for the BGP speaker.
- `peer_weight` - (Optional) The weight added to routes learned from this BGP speaker.
- `peering_addresses` - (Optional) BGP peering address configuration per IP configuration. Map key is arbitrary.
  - `ip_configuration_name` - The name of the IP configuration this peering address applies to.
  - `custom_ips` - (Optional) Custom BGP IP addresses for the peering.
DESCRIPTION
}

variable "default_local_network_gateway_resource_id" {
  type        = string
  default     = null
  description = "The resource ID of the local network gateway that represents the local site with default routes (used for forced tunneling)."
}

variable "diagnostic_settings" {
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of diagnostic settings to create on the Key Vault. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `name` - (Optional) The name of the diagnostic setting. One will be generated if not set, however this will not be unique if you want to create multiple diagnostic setting resources.
  - `log_categories` - (Optional) A set of log categories to send to the log analytics workspace. Defaults to `[]`.
  - `log_groups` - (Optional) A set of log groups to send to the log analytics workspace. Defaults to `["allLogs"]`.
  - `metric_categories` - (Optional) A set of metric categories to send to the log analytics workspace. Defaults to `["AllMetrics"]`.
  - `log_analytics_destination_type` - (Optional) The destination type for the diagnostic setting. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
  - `workspace_resource_id` - (Optional) The resource ID of the log analytics workspace to send logs and metrics to.
  - `storage_account_resource_id` - (Optional) The resource ID of the storage account to send logs and metrics to.
  - `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the event hub authorization rule to send logs and metrics to.
  - `event_hub_name` - (Optional) The name of the event hub. If none is specified, the default event hub will be selected.
  - `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace resource to which you would like to send Diagnostic LogsLogs.
  DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: 'Dedicated', 'AzureDiagnostics'."
  }
  validation {
    condition = alltrue(
      [
        for _, v in var.diagnostic_settings :
        v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
      ]
    )
    error_message = "At least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id`, must be set."
  }
}

variable "enable_bgp" {
  type        = bool
  default     = false
  description = "Whether BGP is enabled for the virtual network gateway."
  nullable    = false
}

variable "enable_bgp_route_translation_for_nat" {
  type        = bool
  default     = false
  description = "Whether BGP route translation for NAT is enabled."
  nullable    = false
}

variable "enable_dns_forwarding" {
  type        = bool
  default     = null
  description = "Whether DNS forwarding is enabled. Only supported on certain ExpressRoute gateway SKUs."
}

variable "enable_private_ip_address" {
  type        = bool
  default     = false
  description = "Whether private IP needs to be enabled on the gateway for connections."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = true
  description = <<DESCRIPTION
This variable controls whether or not telemetry is enabled for the module.
For more information see <https://aka.ms/avm/telemetryinfo>.
If it is set to false, then no telemetry will be collected.
DESCRIPTION
  nullable    = false
}

variable "expressroute_connections" {
  type = map(object({
    name                              = optional(string, null)
    express_route_circuit_resource_id = string
    authorization_key                 = optional(string, null)
    authorization_key_version         = optional(string, "1")
    routing_weight                    = optional(number, null)
    express_route_gateway_bypass      = optional(bool, false)
    enable_private_link_fast_path     = optional(bool, false)
    tags                              = optional(map(string), null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of ExpressRoute connections (`Microsoft.Network/connections` with `connectionType = ExpressRoute`) to create between this virtual network gateway and one or more ExpressRoute circuits. The map key is arbitrary and is used as the default connection `name` when not provided.

- `name` - (Optional) The name of the connection. Defaults to the map key.
- `express_route_circuit_resource_id` - The resource ID of the ExpressRoute circuit to connect the gateway to.
- `authorization_key` - (Optional, sensitive) Authorization key. Required when the circuit is in a different subscription/tenant.
- `authorization_key_version` - (Optional) Increment to rotate `authorization_key`. Defaults to `"1"`.
- `routing_weight` - (Optional) The routing weight for the connection.
- `express_route_gateway_bypass` - (Optional) Bypass the ExpressRoute gateway for data forwarding (FastPath). Defaults to `false`.
- `enable_private_link_fast_path` - (Optional) Enable Private Link FastPath. Requires `express_route_gateway_bypass = true` and a supported gateway SKU. Defaults to `false`.
- `tags` - (Optional) Tags applied to the connection. Defaults to the gateway's `tags`.
DESCRIPTION
  nullable    = false
}

variable "gateway_type" {
  type        = string
  default     = "Vpn"
  description = "The type of virtual network gateway. Possible values are `Vpn` and `ExpressRoute`."
  nullable    = false

  validation {
    condition     = contains(["Vpn", "ExpressRoute"], var.gateway_type)
    error_message = "`gateway_type` must be either `Vpn` or `ExpressRoute`."
  }
}

variable "ipsec_site_to_site_connections" {
  type = map(object({
    connection_name = optional(string, null)
    local_network_gateway = object({
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
    shared_key                         = string
    shared_key_version                 = optional(string, "1")
    outbound_certificate_path          = optional(string, null)
    inbound_certificate_subject_name   = optional(string, null)
    inbound_certificate_chain          = optional(list(string), null)
    connection_protocol                = optional(string, null)
    connection_mode                    = optional(string, null)
    routing_weight                     = optional(number, null)
    dpd_timeout_seconds                = optional(number, null)
    enable_bgp                         = optional(bool, false)
    use_policy_based_traffic_selectors = optional(bool, false)
    express_route_gateway_bypass       = optional(bool, false)
    ipsec_policies = optional(list(object({
      sa_lifetime_seconds    = number
      sa_data_size_kilobytes = number
      ipsec_encryption       = string
      ipsec_integrity        = string
      ike_encryption         = string
      ike_integrity          = string
      dh_group               = string
      pfs_group              = string
    })), null)
    traffic_selector_policies = optional(list(object({
      local_address_ranges  = list(string)
      remote_address_ranges = list(string)
    })), null)
    ingress_nat_rule_resource_ids = optional(list(string), [])
    egress_nat_rule_resource_ids  = optional(list(string), [])
    gateway_custom_bgp_ip_addresses = optional(list(object({
      ip_configuration_name = string
      custom_bgp_ip_address = string
    })), null)
    tags = optional(map(string), null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of IPsec site-to-site connections to create on this virtual network gateway. Each entry deploys a local network gateway and a `Microsoft.Network/connections` resource via the `ipsec-site-to-site` submodule. The map key is arbitrary and is used as the default `connection_name` when not provided.

- `connection_name` - (Optional) The name of the connection. Defaults to the map key.
- `local_network_gateway` - The on-premises endpoint definition.
  - `name` - The name of the local network gateway.
  - `address_space` - List of CIDR blocks describing the on-premises network.
  - `gateway_ip_address` - (Optional) Public IPv4 of the on-premises device. One of `gateway_ip_address` or `fqdn` must be provided.
  - `fqdn` - (Optional) FQDN of the on-premises device.
  - `bgp_settings` - (Optional) BGP settings for the local network gateway (`asn`, `bgp_peering_address`, `peer_weight`).
- `shared_key` - The IPsec shared key (PSK).
- `shared_key_version` - (Optional) Increment to rotate `shared_key`. Defaults to `"1"`.
- `outbound_certificate_path` - (Optional) Key Vault **certificate** URI (`https://<vault>.vault.azure.net/certificates/<name>[/<version>]`) for the certificate used by this gateway to authenticate outbound on the connection. Must reference a `certificates/` object (not a `secrets/` object). Requires the gateway to have a managed identity with access to the Key Vault.
- `inbound_certificate_subject_name` - (Optional) Distinguished/Subject Name (e.g. `CN=peer-ipsec`) that the peer's certificate must present for inbound authentication.
- `inbound_certificate_chain` - (Optional) List of public certificates of the peer used to validate inbound authentication, each entry as base64-encoded DER (PEM body without the `-----BEGIN/END CERTIFICATE-----` lines).
- `connection_protocol` - (Optional) `IKEv1` or `IKEv2`.
- `connection_mode` - (Optional) `Default`, `ResponderOnly`, or `InitiatorOnly`.
- `routing_weight` - (Optional) The routing weight for the connection.
- `dpd_timeout_seconds` - (Optional) The dead peer detection timeout in seconds.
- `enable_bgp` - (Optional) Whether BGP is enabled for this connection. Defaults to `false`.
- `use_policy_based_traffic_selectors` - (Optional) Whether to enable policy-based traffic selectors. Defaults to `false`.
- `express_route_gateway_bypass` - (Optional) Bypass ExpressRoute Gateway for data forwarding. Defaults to `false`.
- `ipsec_policies` - (Optional) Custom IPsec/IKE policies for the connection.
- `traffic_selector_policies` - (Optional) Traffic selector policies (used when `use_policy_based_traffic_selectors` is `true`).
- `ingress_nat_rule_resource_ids` - (Optional) NAT rule resource IDs to apply as ingress rules on this connection.
- `egress_nat_rule_resource_ids` - (Optional) NAT rule resource IDs to apply as egress rules on this connection.
- `gateway_custom_bgp_ip_addresses` - (Optional) Per-connection mapping of the Azure-side APIPA BGP IPs to gateway IP configurations. Required when the gateway's `bgp_settings.peering_addresses.<key>.custom_ips` is used.
  - `ip_configuration_name` - The name of the gateway IP configuration (matches a key/`name` in `ip_configurations`).
  - `custom_bgp_ip_address` - The APIPA IP from the gateway's `custom_ips` to bind to this connection.
- `tags` - (Optional) Tags for the local network gateway and connection. Defaults to the gateway's `tags`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.ipsec_site_to_site_connections :
      v.local_network_gateway.gateway_ip_address != null || v.local_network_gateway.fqdn != null
    ])
    error_message = "Each `local_network_gateway` must specify either `gateway_ip_address` or `fqdn`."
  }
  validation {
    condition = alltrue([
      for _, v in var.ipsec_site_to_site_connections :
      v.connection_protocol == null || contains(["IKEv1", "IKEv2"], coalesce(v.connection_protocol, "IKEv2"))
    ])
    error_message = "`connection_protocol` must be `IKEv1` or `IKEv2`."
  }
  validation {
    condition = alltrue([
      for _, v in var.ipsec_site_to_site_connections :
      v.connection_mode == null || contains(["Default", "ResponderOnly", "InitiatorOnly"], coalesce(v.connection_mode, "Default"))
    ])
    error_message = "`connection_mode` must be `Default`, `ResponderOnly`, or `InitiatorOnly`."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  default     = null
  description = <<DESCRIPTION
  Controls the Resource Lock configuration for this resource. The following properties can be specified:

  - `kind` - (Required) The type of lock. Possible values are `\"CanNotDelete\"` and `\"ReadOnly\"`.
  - `name` - (Optional) The name of the lock. If not specified, a name will be generated based on the `kind` value. Changing this forces the creation of a new resource.
  DESCRIPTION

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be either `\"CanNotDelete\"` or `\"ReadOnly\"`."
  }
}

variable "maintenance_configurations" {
  type = map(object({
    name            = optional(string, null)
    assignment_name = optional(string, null)
    maintenance_window = object({
      start_date_time = string
      duration        = string
      time_zone       = optional(string, "UTC")
      recur_every     = string
    })
    tags = optional(map(string), null)
  }))
  default     = {}
  description = <<DESCRIPTION
A map of customer-controlled maintenance configurations to create and assign to this virtual network gateway. Each entry produces a `Microsoft.Maintenance/maintenanceConfigurations` resource (with `maintenanceScope = "Resource"` and sub-scope `NetworkGatewayMaintenance`) plus the matching `configurationAssignments` child under the gateway. The map key is arbitrary and is used as the default `name` when not provided.

- `name` - (Optional) The name of the maintenance configuration. Defaults to the map key.
- `assignment_name` - (Optional) The name of the `configurationAssignments` resource bound to the gateway. Defaults to `name`.
- `maintenance_window` - The window definition:
  - `start_date_time` - Window anchor in `YYYY-MM-DD HH:MM` format. Only anchors the recurrence.
  - `duration` - Window length as `HH:MM`. Azure currently enforces a minimum of 5 hours (`"05:00"`) for the `NetworkGatewayMaintenance` sub-scope.
  - `time_zone` - (Optional) Time zone identifier. Defaults to `UTC`.
  - `recur_every` - Recurrence expression accepted by the Maintenance API (e.g. `"1Day"`, `"Week Saturday"`, `"Week Saturday,Sunday"`).
- `tags` - (Optional) Tags applied to the maintenance configuration. Defaults to the gateway's `tags`.
DESCRIPTION
  nullable    = false

  validation {
    condition = alltrue([
      for _, v in var.maintenance_configurations :
      can(regex("^[0-9]{2}:[0-9]{2}$", v.maintenance_window.duration))
    ])
    error_message = "`maintenance_window.duration` must be in `HH:MM` format (e.g. `\"05:00\"`)."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  default     = {}
  description = <<DESCRIPTION
  Controls the Managed Identity configuration on this resource. The following properties can be specified:

  - `system_assigned` - (Optional) Specifies if the System Assigned Managed Identity should be enabled.
  - `user_assigned_resource_ids` - (Optional) Specifies a list of User Assigned Managed Identity resource IDs to be assigned to this resource.
  DESCRIPTION
  nullable    = false
}

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
  default     = {}
  description = <<DESCRIPTION
A map of NAT rules to create on this virtual network gateway via the `nat-rules` submodule. Map keys are arbitrary and are used as the default `name` when not provided. NAT rules are commonly used to resolve overlapping address spaces between Azure and on-premises networks.

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

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
  A map of role assignments to create on the <RESOURCE>. The map key is deliberately arbitrary to avoid issues where map keys maybe unknown at plan time.

  - `role_definition_id_or_name` - The ID or name of the role definition to assign to the principal.
  - `principal_id` - The ID of the principal to assign the role to.
  - `description` - (Optional) The description of the role assignment.
  - `skip_service_principal_aad_check` - (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. Defaults to false.
  - `condition` - (Optional) The condition which will be used to scope the role assignment.
  - `condition_version` - (Optional) The version of the condition syntax. Leave as `null` if you are not using a condition, if you are then valid values are '2.0'.
  - `delegated_managed_identity_resource_id` - (Optional) The delegated Azure Resource Id which contains a Managed Identity. Changing this forces a new resource to be created. This field is only used in cross-tenant scenario.
  - `principal_type` - (Optional) The type of the `principal_id`. Possible values are `User`, `Group` and `ServicePrincipal`. It is necessary to explicitly set this attribute when creating role assignments if the principal creating the assignment is constrained by ABAC rules that filters on the PrincipalType attribute.

  > Note: only set `skip_service_principal_aad_check` to true if you are assigning a role to a service principal.
  DESCRIPTION
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "(Optional) Tags of the resource."
}

variable "vpn_client_configuration" {
  type = object({
    address_space = list(string)
    aad_authentication = optional(object({
      tenant   = string
      audience = string
      issuer   = string
    }), null)
    ipsec_policies = optional(list(object({
      sa_lifetime_seconds    = number
      sa_data_size_kilobytes = number
      ipsec_encryption       = string
      ipsec_integrity        = string
      ike_encryption         = string
      ike_integrity          = string
      dh_group               = string
      pfs_group              = string
    })), null)
    radius = optional(object({
      server_address = optional(string, null)
      server_secret  = optional(string, null)
      servers = optional(list(object({
        address = string
        secret  = string
        score   = number
      })), null)
    }), null)
    radius_version = optional(string, "1")
    root_certificates = optional(map(object({
      public_cert_data = string
    })), {})
    revoked_certificates = optional(map(object({
      thumbprint = string
    })), {})
    vpn_client_protocols     = optional(list(string), ["OpenVPN"])
    vpn_authentication_types = optional(list(string), ["Certificate"])
  })
  default     = null
  description = <<DESCRIPTION
Point-to-Site (P2S) VPN client configuration. Set to `null` to disable.

- `address_space` - VPN client address pool. List of CIDR blocks reserved for P2S VPN clients (e.g. `["172.16.201.0/24"]`).
- `aad_authentication` - Azure AD authentication settings. Required when `vpn_authentication_types` contains `AAD`.
  - `tenant` - The AAD tenant URL (e.g. `https://login.microsoftonline.com/<tenant-id>`).
  - `audience` - The Azure VPN application audience.
  - `issuer` - The AAD issuer URL.
- `ipsec_policies` - Custom IPsec/IKE policies for the P2S VPN client configuration.
- `radius` - RADIUS authentication settings. Used when `vpn_authentication_types` contains `Radius`.
  - `server_address` - Single RADIUS server address (mutually exclusive with `servers`).
  - `server_secret` - Shared secret for the single RADIUS server.
  - `servers` - List of RADIUS servers for multi-server configuration (each with `address`, `secret`, and `score`).
- `radius_version` - Increment to force the RADIUS shared secret(s) to be re-sent to Azure when rotated. Defaults to `"1"`.
- `root_certificates` - Map of trusted root certificates used for `Certificate` based authentication. Map key is the certificate name; `public_cert_data` is the base64-encoded public certificate data (without `BEGIN/END CERTIFICATE` headers).
- `revoked_certificates` - Map of revoked client certificates. Map key is the certificate name; `thumbprint` is the certificate thumbprint.
- `vpn_client_protocols` - List of allowed VPN client protocols. Valid values: `IkeV2`, `SSTP`, `OpenVPN`. Defaults to `["OpenVPN"]`.
- `vpn_authentication_types` - List of allowed VPN client authentication types. Valid values: `Certificate`, `Radius`, `AAD`. Defaults to `["Certificate"]`.
DESCRIPTION
  sensitive   = true

  validation {
    condition     = var.vpn_client_configuration == null ? true : length(var.vpn_client_configuration.address_space) > 0
    error_message = "`vpn_client_configuration.address_space` must contain at least one CIDR block."
  }
  validation {
    condition = var.vpn_client_configuration == null ? true : alltrue([
      for p in var.vpn_client_configuration.vpn_client_protocols : contains(["IkeV2", "SSTP", "OpenVPN"], p)
    ])
    error_message = "`vpn_client_configuration.vpn_client_protocols` entries must be one of `IkeV2`, `SSTP`, or `OpenVPN`."
  }
  validation {
    condition = var.vpn_client_configuration == null ? true : alltrue([
      for t in var.vpn_client_configuration.vpn_authentication_types : contains(["Certificate", "Radius", "AAD"], t)
    ])
    error_message = "`vpn_client_configuration.vpn_authentication_types` entries must be one of `Certificate`, `Radius`, or `AAD`."
  }
}

variable "vpn_gateway_generation" {
  type        = string
  default     = "Generation1"
  description = "The VPN gateway generation. Must be `None` for ExpressRoute gateways. Otherwise `Generation1` or `Generation2`."
  nullable    = false

  validation {
    condition     = contains(["None", "Generation1", "Generation2"], var.vpn_gateway_generation)
    error_message = "`vpn_gateway_generation` must be one of `None`, `Generation1`, or `Generation2`."
  }
}

variable "vpn_type" {
  type        = string
  default     = "RouteBased"
  description = "The routing type of the VPN gateway. Possible values are `RouteBased` and `PolicyBased`. Ignored for ExpressRoute gateways."
  nullable    = false

  validation {
    condition     = contains(["RouteBased", "PolicyBased"], var.vpn_type)
    error_message = "`vpn_type` must be `RouteBased` or `PolicyBased`."
  }
}
