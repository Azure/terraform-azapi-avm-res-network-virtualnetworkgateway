## Point-to-Site VPN Example

This example deploys a VPN virtual network gateway with Point-to-Site (P2S) VPN client configuration using the OpenVPN protocol and certificate authentication. A self-signed root certificate is generated using the `tls` provider and configured as a trusted P2S root certificate on the gateway.

## Resources Deployed by this Example

- Resource Group
- Virtual Network with a `GatewaySubnet`
- Standard SKU Public IP Address
- Virtual Network Gateway (`VpnGw1`, route-based) with P2S VPN client configuration
- Self-signed root certificate (via the `tls` provider)

## Important Notes

- The self-signed root certificate is generated for example purposes only. Production deployments should use a properly issued certificate from your enterprise PKI.
- Once deployed, end-user client certificates must be issued from the root certificate and installed on client machines to establish the VPN connection.
- The P2S address pool (`172.16.201.0/24`) must not overlap with the virtual network address space or any on-premises network.
