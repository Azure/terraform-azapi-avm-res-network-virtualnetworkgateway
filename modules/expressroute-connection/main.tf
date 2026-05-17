data "azapi_client_config" "current" {}

locals {
  resource_group_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
}

# Microsoft.Network/connections of type ExpressRoute wires a virtual network
# gateway (gatewayType = ExpressRoute) to a single ExpressRoute circuit.
# This is the standard "ExpressRoute connection" exposed on a vnet gateway.
# Circuit-to-circuit Global Reach is a separate feature and is not handled
# here.
resource "azapi_resource" "this" {
  location  = var.location
  name      = var.name
  parent_id = local.resource_group_id
  type      = "Microsoft.Network/connections@2024-07-01"
  body = {
    properties = {
      connectionType = "ExpressRoute"
      virtualNetworkGateway1 = {
        id = var.virtual_network_gateway_resource_id
      }
      peer = {
        id = var.express_route_circuit_resource_id
      }
      routingWeight             = var.routing_weight
      expressRouteGatewayBypass = var.express_route_gateway_bypass
      enablePrivateLinkFastPath = var.enable_private_link_fast_path
    }
  }
  response_export_values = [
    "id",
    "name",
    "properties.connectionStatus",
    "properties.provisioningState",
  ]
  schema_validation_enabled = false
  sensitive_body = var.authorization_key == null ? null : {
    properties = { authorizationKey = var.authorization_key }
  }
  sensitive_body_version = var.authorization_key == null ? null : {
    "properties.authorizationKey" = var.authorization_key_version
  }
  tags = var.tags
}

