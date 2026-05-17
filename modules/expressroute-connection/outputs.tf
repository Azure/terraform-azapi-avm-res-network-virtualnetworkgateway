output "name" {
  description = "The name of the ExpressRoute connection."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full AzAPI resource object for the ExpressRoute connection."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the ExpressRoute connection."
  value       = azapi_resource.this.id
}
