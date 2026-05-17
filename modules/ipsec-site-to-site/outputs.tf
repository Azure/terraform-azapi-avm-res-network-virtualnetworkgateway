output "connection" {
  description = "The full AzAPI resource object for the IPsec connection."
  value       = azapi_resource.connection
}

output "connection_resource_id" {
  description = "The resource ID of the IPsec connection."
  value       = azapi_resource.connection.id
}

output "local_network_gateway" {
  description = "The full AzAPI resource object for the local network gateway."
  value       = azapi_resource.local_network_gateway
}

output "local_network_gateway_resource_id" {
  description = "The resource ID of the local network gateway."
  value       = azapi_resource.local_network_gateway.id
}
