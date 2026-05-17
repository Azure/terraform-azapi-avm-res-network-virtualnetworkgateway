# ipsec-site-to-site submodule

Creates the resources required to establish a Site-to-Site (S2S) IPsec VPN connection between an Azure virtual network gateway and an on-premises VPN device:

- `Microsoft.Network/localNetworkGateways` - the on-premises representation
- `Microsoft.Network/connections` - the IPsec virtual network gateway connection (`connectionType = IPsec`)

Optionally supports custom IPsec/IKE policies, policy-based traffic selectors, BGP, and ingress/egress NAT rule references.

The shared key is passed via the AzAPI `sensitive_body` to keep it out of plan output. Increment `shared_key_version` when rotating the key.

References:

- <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/connections>
- <https://learn.microsoft.com/en-us/azure/templates/microsoft.network/localnetworkgateways>
