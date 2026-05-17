## Active-Active VPN Gateway with Multiple IP Configurations

This example deploys an active-active route-based VPN virtual network gateway with two IP configurations inside a virtual network. Active-active mode requires exactly two IP configurations, each associated with its own public IP address.

## Resources Deployed by this Example

- Resource Group
- Virtual Network with a `GatewaySubnet`
- Two zone-redundant Standard SKU Public IP Addresses
- Active-active Virtual Network Gateway (`VpnGw2AZ`, route-based)

## Important Notes

- Virtual network gateway deployments typically take **30–45 minutes** to complete.
- Active-active gateways require **two** IP configurations and **two** public IP addresses.
- The `GatewaySubnet` must exist in the virtual network and be at least `/27` in size.
