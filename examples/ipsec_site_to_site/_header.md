## IPsec Site-to-Site VPN Example with Key Vault Backed Authentication

This example deploys two Azure VPN virtual network gateways that face each other across an IPsec site-to-site tunnel:

- A `cloud` gateway hosted inside a `cloud` virtual network (`10.10.0.0/16`).
- An `on-prem` gateway hosted inside a separate `onprem` virtual network (`10.20.0.0/16`).

The second VNet stands in for an on-premises datacenter so the IPsec tunnel can be exercised end-to-end inside a single example deployment. Each gateway is paired with its peer via a local network gateway that points at the other side's public IP, producing a fully bidirectional IKEv2 tunnel.

The IPsec authentication credential is sourced from an Azure Key Vault certificate rather than a static literal value:

1. A **user assigned managed identity** is created and attached to both virtual network gateways. This is the identity the gateways use to access Key Vault.
2. A **Key Vault** with RBAC authorization is deployed in the same resource group. The current Terraform principal is granted `Key Vault Certificates Officer` so it can generate the certificate.
3. A **self-signed certificate** is generated inside the Key Vault using `azurerm_key_vault_certificate`. The certificate's lifecycle (rotation, expiry) is managed by Key Vault.
4. The gateway's user assigned identity is granted `Key Vault Certificate User` and `Key Vault Secrets User` on the Key Vault, giving it read access to the certificate and its backing PKCS#12 secret.
5. The IPsec pre-shared key for both connections is derived as `sha256(certificate.thumbprint)`. Both sides of the tunnel use the same shared key, so the IKEv2 handshake succeeds, and rotating the certificate in Key Vault automatically rotates the IPsec credential.

## Resources Deployed by this Example

- Resource Group
- Two Virtual Networks (`cloud`, `onprem`), each with a `GatewaySubnet`
- Two Standard SKU, zone-redundant Public IP Addresses (one per gateway)
- User Assigned Managed Identity (attached to both gateways)
- Key Vault (RBAC enabled) with role assignments for:
  - The deploying principal (`Key Vault Certificates Officer`)
  - The gateway's user assigned identity (`Key Vault Certificate User`, `Key Vault Secrets User`)
- Key Vault Certificate (self-signed, RSA 2048, auto-renew policy)
- Two Virtual Network Gateways (`VpnGw1AZ`, route-based) -- one `cloud`, one `onprem`
- Two Local Network Gateways -- one representing each side of the tunnel
- Two IPsec Virtual Network Gateway Connections (IKEv2) wired bidirectionally between the gateways

## Topology

```text
                       Key Vault (RBAC)
                       +---------------+
                       | cert: ipsec-  |
                       | tunnel-auth   |
                       +-------+-------+
                               |
            Certificate User / Secrets User role
                               |
                  +------------+------------+
                  |  User Assigned Identity |
                  +------------+------------+
                               |
              attached to both gateways below
                               |
   +-----------+        +------+------+        +-----------+
   |  cloud    |  IPsec |   cloud     |  IPsec |  onprem   |
   |  workload +--------+ VPN gateway +========+ VPN       |
   |  10.10.   |  LNG   | (VpnGw1AZ)  |  IKEv2 | gateway   |
   |  0.0/16   |        +-------------+        | (VpnGw1AZ)|
   +-----------+                               +-----+-----+
                                                     |
                                              +------+------+
                                              |  onprem     |
                                              |  workload   |
                                              |  10.20.0.0/16|
                                              +-------------+
```

## Important Notes

- The "on-prem" side is a second Azure VNet acting as a stand-in. In a real deployment the on-prem gateway and local network gateway would point at an on-premises VPN device's public IP and CIDR ranges.
- Azure IPsec site-to-site connections authenticate with a pre-shared key (PSK). This example demonstrates the Key Vault + managed identity integration pattern by deriving the PSK deterministically from the certificate's thumbprint. The certificate therefore becomes the rotation anchor for the IPsec credential, even though the underlying protocol still uses PSK.
- The Key Vault uses `enable_rbac_authorization = true`. The role assignments include a 60 second propagation delay (`time_sleep`) before the certificate is created.
- `purge_protection_enabled` is set to `false` on the Key Vault so the example can be destroyed cleanly during testing. Production deployments should enable purge protection.
- Both gateways use the zone-redundant `VpnGw1AZ` SKU. Adjust the SKU and `vpn_gateway_generation` if BGP, active-active, or higher throughput is needed.
