output "assignment_resource_id" {
  description = "The resource ID of the `configurationAssignments` child resource that binds the maintenance configuration to the virtual network gateway."
  value       = azapi_resource.assignment.id
}

output "name" {
  description = "The name of the maintenance configuration."
  value       = azapi_resource.this.name
}

output "resource" {
  description = "The full AzAPI resource object for the maintenance configuration."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the maintenance configuration."
  value       = azapi_resource.this.id
}
