## VPN Gateway with NAT Rules Example

This example deploys a `VpnGw2` route-based VPN virtual network gateway and attaches NAT rules using the [`nat-rules`](../../modules/nat-rules) submodule. NAT rules are commonly used to resolve overlapping address spaces between Azure and on-premises networks across IPsec connections.

## Resources Deployed by this Example

- Resource Group
- Virtual Network with a `GatewaySubnet`
- Standard SKU Public IP Address
- Virtual Network Gateway (`VpnGw2`, route-based)
- One `EgressSnat` NAT rule (translates `10.50.0.0/16` → `10.150.0.0/16`)
- One `IngressSnat` NAT rule (translates `192.168.0.0/24` → `172.16.0.0/24`)

## Important Notes

- NAT rules are only supported on `VpnGw2`/`VpnGw2AZ` SKUs and higher.
- The `EgressSnat` mode applies SNAT on egress (typically for Azure VNet space), while `IngressSnat` applies SNAT on ingress (typically for the remote/on-premises space).
- NAT rules must be referenced from the IPsec connection (`ingress_nat_rule_resource_ids` / `egress_nat_rule_resource_ids` on the [`ipsec-site-to-site`](../../modules/ipsec-site-to-site) submodule) to be applied to a tunnel.
