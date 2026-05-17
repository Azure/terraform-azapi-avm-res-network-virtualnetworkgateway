locals {
  # Azure auto-populates bgpSettings on active-active VPN gateways even when
  # BGP is not explicitly configured. Only emit the key in the body when the
  # user supplied bgp_settings, otherwise omit it entirely so the server-side
  # defaults don't cause persistent drift.
  bgp_settings_body = var.bgp_settings == null ? {} : {
    bgpSettings = {
      asn        = var.bgp_settings.asn
      peerWeight = var.bgp_settings.peer_weight
      bgpPeeringAddresses = [
        for k, v in var.bgp_settings.peering_addresses : {
          ipconfigurationId    = "${local.gateway_resource_id}/ipConfigurations/${v.ip_configuration_name}"
          customBgpIpAddresses = v.custom_ips
        }
      ]
    }
  }
  # Full gateway body. Null-valued fields are removed by AzAPI, so we can
  # assign them unconditionally instead of building via merge().
  gateway_properties = merge({
    gatewayType                     = var.gateway_type
    sku                             = { name = var.sku, tier = var.sku }
    activeActive                    = var.active_active
    enableBgp                       = var.enable_bgp
    enablePrivateIpAddress          = var.enable_private_ip_address
    enableBgpRouteTranslationForNat = var.enable_bgp_route_translation_for_nat
    enableDnsForwarding             = var.enable_dns_forwarding
    vpnType                         = var.gateway_type == "Vpn" ? var.vpn_type : null
    vpnGatewayGeneration            = var.gateway_type == "Vpn" ? var.vpn_gateway_generation : null
    gatewayDefaultSite              = var.default_local_network_gateway_resource_id == null ? null : { id = var.default_local_network_gateway_resource_id }

    ipConfigurations = [
      for k, v in var.ip_configurations : {
        name = coalesce(v.name, k)
        properties = {
          privateIPAllocationMethod = v.private_ip_allocation_method
          subnet                    = { id = v.subnet_resource_id }
          publicIPAddress           = v.public_ip_address_resource_id == null ? null : { id = v.public_ip_address_resource_id }
        }
      }
    ]

    vpnClientConfiguration = local.vpn_client_configuration_body
  }, local.bgp_settings_body)
  # Gateway resource ID used to qualify child IP configuration references
  # (e.g. BGP peering addresses) inside the gateway body.
  gateway_resource_id = "${local.resource_group_id}/providers/Microsoft.Network/virtualNetworkGateways/${var.name}"
  # Point-to-Site VPN client configuration helpers. Sensitive RADIUS secrets
  # are sent via sensitive_body so they are not stored in plan output.
  has_radius_servers = var.vpn_client_configuration != null && try(var.vpn_client_configuration.radius.servers, null) != null
  has_radius_single  = var.vpn_client_configuration != null && try(var.vpn_client_configuration.radius.server_address, null) != null
  has_sensitive_vpn_client_configuration = (
    var.vpn_client_configuration != null && length(local.sensitive_vpn_client_configuration) > 0
  )
  identity_block = local.identity_type == "" ? null : {
    type = local.identity_type
    userAssignedIdentities = length(var.managed_identities.user_assigned_resource_ids) == 0 ? null : {
      for id in var.managed_identities.user_assigned_resource_ids : id => {}
    }
  }
  # Managed identity block. AzAPI strips null fields from the body, so we
  # only need to compute the type string and (optionally) the user-assigned
  # identity map.
  identity_type = join(", ", compact([
    var.managed_identities.system_assigned ? "SystemAssigned" : "",
    length(var.managed_identities.user_assigned_resource_ids) > 0 ? "UserAssigned" : "",
  ]))
  # Parent resource group resource ID for AzAPI.
  resource_group_id                  = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
  sensitive_vpn_client_configuration = var.vpn_client_configuration == null ? {} : merge(
    local.has_radius_single && try(var.vpn_client_configuration.radius.server_secret, null) != null ? {
      radiusServerSecret = var.vpn_client_configuration.radius.server_secret
    } : {},
    local.has_radius_servers ? {
      radiusServers = [
        for s in var.vpn_client_configuration.radius.servers : {
          radiusServerAddress = s.address
          radiusServerScore   = s.score
          radiusServerSecret  = s.secret
        }
      ]
    } : {},
  )
  vpn_client_configuration_body = var.vpn_client_configuration == null ? null : merge(
    {
      vpnClientAddressPool   = { addressPrefixes = var.vpn_client_configuration.address_space }
      vpnClientProtocols     = var.vpn_client_configuration.vpn_client_protocols
      vpnAuthenticationTypes = var.vpn_client_configuration.vpn_authentication_types
    },
    length(var.vpn_client_configuration.root_certificates) > 0 ? {
      vpnClientRootCertificates = [
        for cert_name, cert in var.vpn_client_configuration.root_certificates : {
          name       = cert_name
          properties = { publicCertData = cert.public_cert_data }
        }
      ]
    } : {},
    length(var.vpn_client_configuration.revoked_certificates) > 0 ? {
      vpnClientRevokedCertificates = [
        for cert_name, cert in var.vpn_client_configuration.revoked_certificates : {
          name       = cert_name
          properties = { thumbprint = cert.thumbprint }
        }
      ]
    } : {},
    var.vpn_client_configuration.aad_authentication != null ? {
      aadTenant   = var.vpn_client_configuration.aad_authentication.tenant
      aadAudience = var.vpn_client_configuration.aad_authentication.audience
      aadIssuer   = var.vpn_client_configuration.aad_authentication.issuer
    } : {},
    local.has_radius_single ? {
      radiusServerAddress = var.vpn_client_configuration.radius.server_address
    } : {},
    local.vpn_client_ipsec_policies != null ? { vpnClientIpsecPolicies = local.vpn_client_ipsec_policies } : {},
  )
  vpn_client_ipsec_policies = var.vpn_client_configuration == null || var.vpn_client_configuration.ipsec_policies == null ? null : [
    for p in var.vpn_client_configuration.ipsec_policies : {
      saLifeTimeSeconds   = p.sa_lifetime_seconds
      saDataSizeKilobytes = p.sa_data_size_kilobytes
      ipsecEncryption     = p.ipsec_encryption
      ipsecIntegrity      = p.ipsec_integrity
      ikeEncryption       = p.ike_encryption
      ikeIntegrity        = p.ike_integrity
      dhGroup             = p.dh_group
      pfsGroup            = p.pfs_group
    }
  ]
}
