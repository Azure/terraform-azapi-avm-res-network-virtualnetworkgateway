## Azure Virtual Network Gateway Deployment Module

This module helps you deploy an Azure Virtual Network Gateway and its related dependencies. Before using this module, be sure to review the official Azure [Virtual Network Gateway Documentation](https://learn.microsoft.com/en-us/azure/vpn-gateway/vpn-gateway-about-vpngateways).

> [!IMPORTANT]
> As the overall [AVM](https://aka.ms/avm) (Azure Verified Modules) framework is not yet GA (Generally Available), the CI (Continuous Integration) framework and test automation may not be fully functional across all supported languages. **Breaking changes** are possible.
>
> However, this **DOES NOT** imply that the modules are unusable. These modules **CAN** be used in all environments—whether dev, test, or production. Treat them as you would any other Infrastructure-as-Code (IaC) module, and feel free to raise issues or request features as you use the module. Be sure to check the release notes before updating to newer versions to review any breaking changes or considerations.

## Resources Deployed by this Module

- Virtual Network Gateway (`Microsoft.Network/virtualNetworkGateways`)
- Resource Lock
- IAM (Identity and Access Management)
- Diagnostic Settings

## Submodules

This module ships with the following submodules to manage related and child resources:

- [`modules/nat-rules`](./modules/nat-rules) — `Microsoft.Network/virtualNetworkGateways/natRules` for VPN NAT rules on the gateway.
- [`modules/expressroute-connection`](./modules/expressroute-connection) — `Microsoft.Network/expressRouteCircuits/peerings/connections` for ExpressRoute Global Reach circuit-to-circuit connections, plus an optional read-only data-source view of the corresponding `peerConnections` resource on the peer circuit.
- [`modules/ipsec-site-to-site`](./modules/ipsec-site-to-site) — end-to-end Site-to-Site IPsec VPN setup including `Microsoft.Network/localNetworkGateways` and `Microsoft.Network/connections`.

Point-to-Site (P2S) VPN client configuration is applied directly through the root module via the `vpn_client_configuration` variable.

## Deployment Process

1. **Deploy the Virtual Network Gateway**: Start by deploying the gateway. The gateway requires a subnet named `GatewaySubnet` in the target virtual network, and (for non-private gateways) at least one Standard SKU public IP address.

2. **Add Connections and Configuration**: Once the gateway is provisioned, attach Site-to-Site IPsec connections, Point-to-Site VPN client configuration, ExpressRoute connections, or NAT rules using the relevant submodules.

> **Note**: Virtual network gateway deployments can take **30–45 minutes**. Dependent resources (connections, NAT rules, P2S configuration) should not be deployed against a gateway that has not yet reached the **Succeeded** provisioning state.

## Important Notes

- **GatewaySubnet Required**: A subnet named exactly `GatewaySubnet` must exist in the virtual network. The subnet should be at least `/27` in size.

- **Gateway Type vs SKU**: The `gateway_type` (`Vpn` or `ExpressRoute`) must be compatible with the chosen `sku`. VPN SKUs (`VpnGw*`) cannot be used with `ExpressRoute` gateways and vice versa. ExpressRoute gateways must set `vpn_gateway_generation = "None"`.

- **Active-Active Gateways**: When `active_active = true`, two IP configurations and two public IP addresses are required.

- **BGP**: Enabling BGP requires `enable_bgp = true` and a valid `bgp_settings` block. The default Azure ASN for VPN gateways is `65515`.

- **Gateway Connection Clarification**: This module deploys a classic **Virtual Network Gateway** used in Virtual Networks. It is distinct from the **ExpressRoute Gateway** resource used in Virtual WANs.

## Feedback

We welcome your feedback! If you encounter any issues or have feature requests, please raise them in the module's GitHub repository.

---
# terraform-azapi-avm-res-network-virtualnetworkgateway

Azure Verified Module (AVM) for Azure Virtual Network Gateway, built on the AzAPI provider.

This module deploys a `Microsoft.Network/virtualNetworkGateways` resource and exposes the following submodules for related child / linked resources:

- [`modules/nat-rules`](./modules/nat-rules) - `Microsoft.Network/virtualNetworkGateways/natRules` (VPN NAT rules on the gateway).
- [`modules/expressroute-connection`](./modules/expressroute-connection) - `Microsoft.Network/expressRouteCircuits/peerings/connections` for ExpressRoute Global Reach circuit-to-circuit connections, plus an optional read-only data-source view of the corresponding `peerConnections` resource on the peer circuit.
- [`modules/ipsec-site-to-site`](./modules/ipsec-site-to-site) - end-to-end Site-to-Site IPsec VPN setup including `Microsoft.Network/localNetworkGateways` and `Microsoft.Network/connections`.

Point-to-Site (P2S) VPN client configuration is applied directly through the root module via the `vpn_client_configuration` variable.
