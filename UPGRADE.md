# Upgrade Guide

## 0.1.0

Initial release. No migrations needed.

### Prerequisites

- Kubernetes >= 1.28
- Helm >= 3.14
- ClickHouse operator chart (`clickhouse-operator-helm`) installed with CRDs

### Notes

- This chart does **not** install CRDs. The ClickHouse operator chart must be installed first.
- The `ClickHouseCluster` and `KeeperCluster` CRDs must be available in the cluster before installing this chart.
