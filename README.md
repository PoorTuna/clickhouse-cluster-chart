# ClickHouse Cluster Helm Chart

Helm chart for deploying `ClickHouseCluster` and `KeeperCluster` custom resources on top of the [official ClickHouse operator](https://github.com/ClickHouse/clickhouse-operator).

This chart does **not** install the operator — that must be installed separately first.

## What gets deployed

| Resource | Toggle | Default |
|---|---|---|
| `ClickHouseCluster` CR | `clickhouseCluster.enabled` | `true` |
| `KeeperCluster` CR | `keeperCluster.enabled` | `true` |
| Default user password `Secret` | `secrets.defaultUserPassword.enabled` | `false` |
| TLS `Secret` | `secrets.tls.enabled` | `false` |
| ClickHouse `ServiceMonitor` | `serviceMonitor.enabled` | `false` |
| Keeper `ServiceMonitor` | `keeperServiceMonitor.enabled` | `false` |
| `PrometheusRule` | `prometheusRule.enabled` | `false` |
| Grafana dashboard `ConfigMap` | `grafanaDashboard.enabled` | `false` |
| `NetworkPolicy` | `networkPolicy.enabled` | `false` |

## Prerequisites

- Kubernetes >= 1.28
- Helm >= 3.14
- ClickHouse operator installed (CRDs: `ClickHouseCluster`, `KeeperCluster`)
- *(Optional)* prometheus-operator for ServiceMonitor / PrometheusRule
- *(Optional)* Grafana with sidecar for dashboard discovery

## Quick start

```bash
# Install the operator first
helm install clickhouse-operator ./clickhouse-operator-helm -n clickhouse-system --create-namespace

# Install a cluster
helm install clickhouse ./clickhouse-cluster-helm -n clickhouse --create-namespace

# Verify
kubectl get chc,chk -n clickhouse
```

With custom values:

```bash
helm install clickhouse ./clickhouse-cluster-helm \
  -f examples/production-values.yaml \
  -n clickhouse --create-namespace
```

## Examples

| File | Description |
|---|---|
| [`minimal-values.yaml`](examples/minimal-values.yaml) | 1 shard / 1 replica + 1 keeper |
| [`dev-values.yaml`](examples/dev-values.yaml) | 1 shard / 2 replicas, debug logging, small PVCs |
| [`production-values.yaml`](examples/production-values.yaml) | 3 shards / 2 replicas, TLS, PDB, monitoring, anti-affinity |
| [`ha-keeper-values.yaml`](examples/ha-keeper-values.yaml) | External keeper reference, no KeeperCluster deployed |
| [`multi-shard-values.yaml`](examples/multi-shard-values.yaml) | 4 shards / 3 replicas with extraConfig |
| [`monitoring-values.yaml`](examples/monitoring-values.yaml) | ServiceMonitors + PrometheusRule + Grafana dashboard |

## Helm tests

```bash
helm test clickhouse -n clickhouse
```

Runs three test pods:
1. `clickhouse-client SELECT 1` against the cluster
2. Keeper `ruok` four-letter command
3. `system.clusters` topology verification

## Configuration

All parameters are documented in [`values.yaml`](values.yaml). Key ones:

### ClickHouseCluster

| Parameter | Type | Default |
|---|---|---|
| `clickhouseCluster.enabled` | `bool` | `true` |
| `clickhouseCluster.shards` | `int` | `1` |
| `clickhouseCluster.replicas` | `int` | `2` |
| `clickhouseCluster.keeperClusterRef.name` | `string` | `""` (auto-derived) |
| `clickhouseCluster.containerTemplate.resources` | `object` | `{}` |
| `clickhouseCluster.dataVolumeClaimSpec.resources.requests.storage` | `string` | `100Gi` |
| `clickhouseCluster.podDisruptionBudget.enabled` | `bool` | `false` |
| `clickhouseCluster.settings.tls.enabled` | `bool` | `false` |
| `clickhouseCluster.settings.extraConfig` | `object` | `{}` |

### KeeperCluster

| Parameter | Type | Default |
|---|---|---|
| `keeperCluster.enabled` | `bool` | `true` |
| `keeperCluster.replicas` | `int` | `3` (must be odd) |
| `keeperCluster.containerTemplate.resources` | `object` | `{}` |
| `keeperCluster.dataVolumeClaimSpec.resources.requests.storage` | `string` | `20Gi` |
| `keeperCluster.settings.tls.enabled` | `bool` | `false` |

### Monitoring

| Parameter | Type | Default |
|---|---|---|
| `serviceMonitor.enabled` | `bool` | `false` |
| `keeperServiceMonitor.enabled` | `bool` | `false` |
| `prometheusRule.enabled` | `bool` | `false` |
| `prometheusRule.defaultRules.enabled` | `bool` | `true` |
| `grafanaDashboard.enabled` | `bool` | `false` |

See `values.yaml` for the full list including secrets, network policies, TLS, logger settings, pod templates, and more.

## Uninstall

```bash
helm uninstall clickhouse -n clickhouse
```

PVCs are retained on uninstall. To clean up data:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=clickhouse -n clickhouse
```

## License

MIT
