## VPN Gateway BGP Example (Cloud + On-prem)

This example deploys two route-based VPN gateways in the same region — a "cloud" side and an "on-prem" side (the on-prem side is itself an Azure VNet/gateway used here to simulate an on-premises VPN device). The two gateways are connected with a pair of IPsec connections (one per direction) and BGP is configured between them so each side learns the other's address space dynamically.

## Resources Deployed by this Example

- Resource Group
- Two Virtual Networks (`cloud` `10.40.0.0/16`, `onprem` `10.50.0.0/16`), each with a `GatewaySubnet`
- Two Standard zonal Public IP Addresses
- Two Virtual Network Gateways (`VpnGw1AZ`, route-based, BGP enabled)
  - Cloud ASN: `65515` (Azure default)
  - On-prem ASN: `65501`
- Two Local Network Gateways (each pointing at the opposite side's public IP and BGP peer address)
- Two `Microsoft.Network/connections` (IPsec, BGP enabled), one per direction, sharing a randomly generated PSK

## Important Notes

- BGP requires `enable_bgp = true` on both the gateway and the connection.
- The local network gateway's `address_space` only needs the remote BGP peer's `/32`; everything else is learned through BGP.
- ASNs `8074-8076`, `8210`, `12076` are reserved by Azure. Use private ASNs in `64512-65534`.
- The remote BGP peer address is read back from the gateway's AzAPI response (`properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]`).
