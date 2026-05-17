## ExpressRoute Gateway and Circuit Connection Example

This example deploys an end-to-end ExpressRoute scenario:

1. An ExpressRoute Direct port (`Microsoft.Network/expressRoutePorts`) with both physical links left administratively disabled so no billing is incurred for the underlying connection.
2. An ExpressRoute circuit (`Microsoft.Network/expressRouteCircuits`) backed by the ExpressRoute Direct port above, provisioned via the [`Azure/avm-res-network-expressroutecircuit/azurerm`](https://registry.terraform.io/modules/Azure/avm-res-network-expressroutecircuit/azurerm/latest) AVM module.
3. An ExpressRoute virtual network gateway (`ErGw1AZ` SKU) created by this module.
4. A `Microsoft.Network/connections` resource of type `ExpressRoute` that connects the virtual network gateway to the ExpressRoute circuit, configured through the `expressroute_connections` input of this module.

## Resources Deployed by this Example

- Resource Group
- Virtual Network with a `GatewaySubnet`
- Standard SKU Public IP Address
- ExpressRoute Direct port (both links `admin_enabled = false`)
- ExpressRoute Circuit (built on the ExpressRoute Direct port)
- Virtual Network Gateway (`ErGw1AZ`, ExpressRoute)
- ExpressRoute Gateway-to-Circuit Connection

## Important Notes

- ExpressRoute gateways must use `vpn_gateway_generation = "None"`.
- ExpressRoute Direct ports are a paid resource even when the links remain disabled in some peering locations. Destroy this example after testing to avoid ongoing charges.
- The Azure subscription must be enabled for ExpressRoute Direct and have available capacity in the chosen `peering_location`.
