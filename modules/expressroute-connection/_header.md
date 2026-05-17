# expressroute-connection submodule

Creates a `Microsoft.Network/expressRouteCircuits/peerings/connections` resource (Global Reach circuit-to-circuit connection) on the local ExpressRoute circuit's private peering.

The corresponding `Microsoft.Network/expressRouteCircuits/peerings/peerConnections` resource on the peer circuit is **read-only** in Azure and cannot be created directly. Set `lookup_peer_connection = true` and supply `peer_connection_resource_id` to read it via a data source.

References:

- <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits/peerings/connections>
- <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/expressroutecircuits/peerings/peerconnections>
