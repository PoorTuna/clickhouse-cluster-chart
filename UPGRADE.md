# Upgrade Guide

## 0.2.1

Fixes resource-name collisions introduced in 0.2.0 and corrects a default.

- Keeper-side K8s objects (ServiceMonitor, NetworkPolicy, test Pod) now use a new `keeperObjectName` helper that appends `-keeper` by default, preventing collisions with the ClickHouse-side objects of the same kind. The `KeeperCluster` CR itself still uses `keeperFullname` (the release name by default).
- Setting `keeperFullnameOverride` uses the value verbatim for both the CR and the keeper-side objects (no extra `-keeper` suffix), so overriding to e.g. `cluster-keeper` does not produce `cluster-keeper-keeper`.
- Default `serviceMonitor.port` and `keeperServiceMonitor.port` changed from `metrics` to `prometheus`, which matches the port name exposed by the Altinity operator's Services when the prometheus endpoint is configured.

Note: `keeperServiceMonitor` still requires the keeper's `<prometheus><endpoint>/metrics</endpoint>...</prometheus>` config block to be enabled before metrics are actually scrapable.

On upgrade from 0.2.0, the keeper ServiceMonitor, NetworkPolicy, and test Pod objects will be renamed (deleted + recreated). No data-carrying resources are affected.

## 0.2.0

Breaking change: default resource names no longer append the chart name or `-keeper` suffix.

- `ClickHouseCluster` CR now defaults to `<release-name>` (previously `<release-name>-<chart-name>` when the release name didn't contain the chart name).
- `KeeperCluster` CR now defaults to `<release-name>` (previously `<release-name>-keeper`).
- New value `keeperFullnameOverride` allows overriding the `KeeperCluster` CR name independently from `fullnameOverride`.

Users upgrading from 0.1.0 whose rendered resource names will change should either set `fullnameOverride` / `keeperFullnameOverride` to preserve the prior names, or plan to recreate the affected resources.

## 0.1.0

Initial release. No migrations needed.

### Prerequisites

- Kubernetes >= 1.28
- Helm >= 3.14
- ClickHouse operator chart (`clickhouse-operator-helm`) installed with CRDs

### Notes

- This chart does **not** install CRDs. The ClickHouse operator chart must be installed first.
- The `ClickHouseCluster` and `KeeperCluster` CRDs must be available in the cluster before installing this chart.
