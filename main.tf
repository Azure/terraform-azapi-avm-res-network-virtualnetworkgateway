data "azapi_client_config" "current" {}

resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.Network/virtualNetworkGateways@2024-07-01"
  body = {
    properties = local.gateway_properties
    identity   = local.identity_block
  }
  create_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  delete_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  # Azure returns identity.type with a lowercase first letter (e.g.
  # "userAssigned") even though the request body uses "UserAssigned". Tell
  # AzAPI to compare the body case-insensitively so this server-side
  # normalization does not cause persistent drift.
  ignore_casing = true
  read_headers  = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null
  response_export_values = [
    "id",
    "name",
    "properties.bgpSettings",
    "properties.inboundDnsForwardingEndpoint",
    "properties.provisioningState",
    "properties.resourceGuid",
    "identity",
  ]
  sensitive_body = local.has_sensitive_vpn_client_configuration ? {
    properties = {
      vpnClientConfiguration = local.sensitive_vpn_client_configuration
    }
  } : null
  sensitive_body_version = local.has_sensitive_vpn_client_configuration ? {
    "properties.vpnClientConfiguration" = var.vpn_client_configuration.radius_version
  } : null
  tags           = var.tags
  update_headers = var.enable_telemetry ? { "User-Agent" : local.avm_azapi_header } : null

  timeouts {
    create = "45m"
  }
}

resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azapi_resource.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.this.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}


resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${var.name}"
  target_resource_id             = azapi_resource.this.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category = enabled_log.value
    }
  }
  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }
  dynamic "enabled_metric" {
    for_each = each.value.metric_categories

    content {
      category = enabled_metric.value
    }
  }
}

module "ipsec_site_to_site_connections" {
  source   = "./modules/ipsec-site-to-site"
  for_each = var.ipsec_site_to_site_connections

  connection_name                     = coalesce(each.value.connection_name, each.key)
  local_network_gateway               = each.value.local_network_gateway
  location                            = var.location
  resource_group_name                 = var.resource_group_name
  shared_key                          = each.value.shared_key
  virtual_network_gateway_resource_id = azapi_resource.this.id
  connection_mode                     = each.value.connection_mode
  connection_protocol                 = each.value.connection_protocol
  dpd_timeout_seconds                 = each.value.dpd_timeout_seconds
  egress_nat_rule_resource_ids        = each.value.egress_nat_rule_resource_ids
  enable_bgp                          = each.value.enable_bgp
  express_route_gateway_bypass        = each.value.express_route_gateway_bypass
  gateway_custom_bgp_ip_addresses     = each.value.gateway_custom_bgp_ip_addresses
  inbound_certificate_chain           = each.value.inbound_certificate_chain
  inbound_certificate_subject_name    = each.value.inbound_certificate_subject_name
  ingress_nat_rule_resource_ids       = each.value.ingress_nat_rule_resource_ids
  ipsec_policies                      = each.value.ipsec_policies
  outbound_certificate_path           = each.value.outbound_certificate_path
  routing_weight                      = each.value.routing_weight
  shared_key_version                  = each.value.shared_key_version
  tags                                = each.value.tags != null ? each.value.tags : var.tags
  traffic_selector_policies           = each.value.traffic_selector_policies
  use_policy_based_traffic_selectors  = each.value.use_policy_based_traffic_selectors

  # NAT rule resource IDs are passed as predicted strings, so Terraform does
  # not infer a dependency between the connection and the NAT rules child
  # module. Without this explicit ordering the connection PUT can run before
  # the NAT rules exist, in which case Azure provisions the connection
  # without the `(ingress|egress)NatRules` linkage even though the body
  # contains the rule IDs.
  depends_on = [module.nat_rules]
}

module "expressroute_connections" {
  source   = "./modules/expressroute-connection"
  for_each = var.expressroute_connections

  express_route_circuit_resource_id   = each.value.express_route_circuit_resource_id
  location                            = var.location
  name                                = coalesce(each.value.name, each.key)
  resource_group_name                 = var.resource_group_name
  virtual_network_gateway_resource_id = azapi_resource.this.id
  authorization_key                   = each.value.authorization_key
  authorization_key_version           = each.value.authorization_key_version
  enable_private_link_fast_path       = each.value.enable_private_link_fast_path
  express_route_gateway_bypass        = each.value.express_route_gateway_bypass
  routing_weight                      = each.value.routing_weight
  tags                                = each.value.tags != null ? each.value.tags : var.tags
}

module "nat_rules" {
  source = "./modules/nat-rules"

  nat_rules                           = var.nat_rules
  virtual_network_gateway_resource_id = azapi_resource.this.id
}

module "maintenance_configurations" {
  source   = "./modules/maintenance-configuration"
  for_each = var.maintenance_configurations

  location                            = var.location
  maintenance_window                  = each.value.maintenance_window
  name                                = coalesce(each.value.name, each.key)
  resource_group_name                 = var.resource_group_name
  virtual_network_gateway_resource_id = azapi_resource.this.id
  assignment_name                     = each.value.assignment_name
  tags                                = each.value.tags != null ? each.value.tags : var.tags
}
