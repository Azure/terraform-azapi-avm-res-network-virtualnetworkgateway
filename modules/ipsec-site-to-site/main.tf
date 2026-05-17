data "azapi_client_config" "current" {}

locals {
  connection_properties = merge(
    {
      connectionType = "IPsec"
      virtualNetworkGateway1 = {
        id         = var.virtual_network_gateway_resource_id
        properties = {}
      }
      localNetworkGateway2 = {
        id         = azapi_resource.local_network_gateway.id
        properties = {}
      }
      enableBgp                      = var.enable_bgp
      usePolicyBasedTrafficSelectors = var.use_policy_based_traffic_selectors
      expressRouteGatewayBypass      = var.express_route_gateway_bypass
    },
    var.connection_protocol != null ? { connectionProtocol = var.connection_protocol } : {},
    var.connection_mode != null ? { connectionMode = var.connection_mode } : {},
    var.routing_weight != null ? { routingWeight = var.routing_weight } : {},
    var.dpd_timeout_seconds != null ? { dpdTimeoutSeconds = var.dpd_timeout_seconds } : {},
    local.ipsec_policies != null ? { ipsecPolicies = local.ipsec_policies } : {},
    local.traffic_selector_policies != null ? { trafficSelectorPolicies = local.traffic_selector_policies } : {},
    length(var.ingress_nat_rule_resource_ids) > 0 ? {
      ingressNatRules = [for id in var.ingress_nat_rule_resource_ids : { id = id }]
    } : {},
    length(var.egress_nat_rule_resource_ids) > 0 ? {
      egressNatRules = [for id in var.egress_nat_rule_resource_ids : { id = id }]
    } : {},
    var.gateway_custom_bgp_ip_addresses != null && length(var.gateway_custom_bgp_ip_addresses) > 0 ? {
      gatewayCustomBgpIpAddresses = [
        for e in var.gateway_custom_bgp_ip_addresses : {
          ipConfigurationId  = "${var.virtual_network_gateway_resource_id}/ipConfigurations/${e.ip_configuration_name}"
          customBgpIpAddress = e.custom_bgp_ip_address
        }
      ]
    } : { gatewayCustomBgpIpAddresses = [] },
    local.use_certificate_authentication ? { authenticationType = "Certificate" } : {},
    local.use_certificate_authentication ? {
      certificateAuthentication = merge(
        var.outbound_certificate_path != null ? { outboundAuthCertificate = var.outbound_certificate_path } : {},
        var.inbound_certificate_subject_name != null ? { inboundAuthCertificateSubjectName = var.inbound_certificate_subject_name } : {},
        var.inbound_certificate_chain != null ? { inboundAuthCertificateChain = var.inbound_certificate_chain } : {},
      )
    } : {},
  )
  ipsec_policies = var.ipsec_policies == null ? null : [
    for p in var.ipsec_policies : {
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
  local_network_gateway_properties = merge(
    {
      localNetworkAddressSpace = {
        addressPrefixes = var.local_network_gateway.address_space
      }
    },
    var.local_network_gateway.gateway_ip_address != null ? {
      gatewayIpAddress = var.local_network_gateway.gateway_ip_address
    } : {},
    var.local_network_gateway.fqdn != null ? {
      fqdn = var.local_network_gateway.fqdn
    } : {},
    var.local_network_gateway.bgp_settings != null ? {
      bgpSettings = merge(
        var.local_network_gateway.bgp_settings.asn != null ? { asn = var.local_network_gateway.bgp_settings.asn } : {},
        var.local_network_gateway.bgp_settings.bgp_peering_address != null ? { bgpPeeringAddress = var.local_network_gateway.bgp_settings.bgp_peering_address } : {},
        var.local_network_gateway.bgp_settings.peer_weight != null ? { peerWeight = var.local_network_gateway.bgp_settings.peer_weight } : {},
      )
    } : {},
  )
  resource_group_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  traffic_selector_policies = var.traffic_selector_policies == null ? null : [
    for p in var.traffic_selector_policies : {
      localAddressRanges  = p.local_address_ranges
      remoteAddressRanges = p.remote_address_ranges
    }
  ]
  use_certificate_authentication = (
    var.outbound_certificate_path != null ||
    var.inbound_certificate_subject_name != null ||
    var.inbound_certificate_chain != null
  )
}

resource "azapi_resource" "local_network_gateway" {
  location  = var.location
  name      = var.local_network_gateway.name
  parent_id = local.resource_group_id
  type      = "Microsoft.Network/localNetworkGateways@2024-07-01"
  body = {
    properties = local.local_network_gateway_properties
  }
  response_export_values = ["id"]
  tags                   = var.tags
}

resource "azapi_resource" "connection" {
  location  = var.location
  name      = var.connection_name
  parent_id = local.resource_group_id
  type      = "Microsoft.Network/connections@2025-05-01"
  body = {
    properties = local.connection_properties
  }
  response_export_values = [
    "id",
    "properties.connectionStatus",
    "properties.provisioningState",
  ]
  schema_validation_enabled = false
  sensitive_body = {
    properties = { sharedKey = var.shared_key }
  }
  sensitive_body_version = {
    "properties.sharedKey" = var.shared_key_version
  }
  tags = var.tags
}
