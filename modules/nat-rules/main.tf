resource "azapi_resource" "this" {
  for_each = var.nat_rules

  name      = coalesce(each.value.name, each.key)
  parent_id = var.virtual_network_gateway_resource_id
  type      = "Microsoft.Network/virtualNetworkGateways/natRules@2024-07-01"
  body = {
    properties = {
      type              = each.value.type
      mode              = each.value.mode
      ipConfigurationId = each.value.ip_configuration_id
      internalMappings = [
        for m in each.value.internal_mappings : {
          addressSpace = m.address_space
          portRange    = m.port_range
        }
      ]
      externalMappings = [
        for m in each.value.external_mappings : {
          addressSpace = m.address_space
          portRange    = m.port_range
        }
      ]
    }
  }
  response_export_values = ["id"]
}
