## Default (Minimal) VPN Gateway Example

This example deploys the module in its simplest form: a basic `VpnGw1` route-based VPN virtual network gateway with a single IP configuration. It is the minimal configuration required to stand up a VPN virtual network gateway.

## Resources Deployed by this Example

- Resource Group
- Virtual Network with a `GatewaySubnet`
- Standard SKU Public IP Address
- Virtual Network Gateway (`VpnGw1`, route-based)

## Important Notes

- Virtual network gateway deployments typically take **30–45 minutes** to complete.
- The `GatewaySubnet` must exist in the virtual network and be at least `/27` in size.
