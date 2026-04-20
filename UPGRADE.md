# Upgrade Guide

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
