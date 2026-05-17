# maintenance-configuration submodule

Creates a `Microsoft.Maintenance/maintenanceConfigurations` resource and the matching `Microsoft.Maintenance/configurationAssignments` child under a virtual network gateway, enabling customer-controlled maintenance windows for VPN / ExpressRoute gateways.

The configuration uses `maintenanceScope = "Resource"` with the `NetworkGatewayMaintenance` sub-scope, which is the public scope Azure exposes for gateway maintenance control.

Notes:

- Azure enforces a minimum window `duration` of 300 minutes (5 hours) for the `NetworkGatewayMaintenance` sub-scope.
- `start_date_time` only anchors the recurrence; the cadence is driven by `recur_every` (e.g. `"1Day"`, `"Week Saturday"`).

References:

- <https://learn.microsoft.com/en-us/azure/templates/microsoft.maintenance/maintenanceconfigurations>
- <https://learn.microsoft.com/en-us/azure/templates/microsoft.maintenance/configurationassignments>
