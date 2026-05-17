output "nat_rules" {
  description = "Map of created NAT rules keyed by the input map key."
  value       = { for k, v in azapi_resource.this : k => v }
}

output "resource_ids" {
  description = "Map of created NAT rule resource IDs keyed by the input map key."
  value       = { for k, v in azapi_resource.this : k => v.id }
}
