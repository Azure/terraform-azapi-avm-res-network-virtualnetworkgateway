output "expressroute_connections" {
  description = "Map of ExpressRoute connection submodule outputs, keyed by the same map key supplied in `var.expressroute_connections`."
  value       = { for k, m in module.expressroute_connections : k => m }
}

output "ipsec_site_to_site_connections" {
  description = "Map of IPsec site-to-site connection submodule outputs, keyed by the same map key supplied in `var.ipsec_site_to_site_connections`."
  value       = { for k, m in module.ipsec_site_to_site_connections : k => m }
}

output "maintenance_configurations" {
  description = "Map of maintenance configuration submodule outputs, keyed by the same map key supplied in `var.maintenance_configurations`."
  value       = { for k, m in module.maintenance_configurations : k => m }
}

output "name" {
  description = "The name of the virtual network gateway."
  value       = azapi_resource.this.name
}

output "nat_rules" {
  description = "Map of NAT rule resource IDs created via `var.nat_rules`, keyed by the same map key."
  value       = module.nat_rules.resource_ids
}

output "resource" {
  description = "The full AzAPI resource object for the virtual network gateway."
  value       = azapi_resource.this
}

output "resource_id" {
  description = "The resource ID of the virtual network gateway."
  value       = azapi_resource.this.id
}

output "system_assigned_mi_principal_id" {
  description = "The principal ID of the system-assigned managed identity, if enabled."
  value       = try(azapi_resource.this.output.identity.principalId, null)
}
