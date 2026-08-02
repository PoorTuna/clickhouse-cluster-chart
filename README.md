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
| ClickHouse HTTP `Ingress` | `ingress.enabled` | `false` |
| ClickHouse HTTP `Route` (OpenShift) | `route.enabled` | `false` |
| S3 quota guard (`clickhouse-s3-guard` subchart) | `clickhouse-s3-guard.enabled` | `false` |

## Prerequisites

- Kubernetes >= 1.28
- Helm >= 3.14
- ClickHouse operator installed (CRDs: `ClickHouseCluster`, `KeeperCluster`)
- *(Optional)* prometheus-operator for ServiceMonitor / PrometheusRule
- *(Optional)* Grafana with sidecar for dashboard discovery
- *(Optional)* a Helm repository serving [`clickhouse-s3-guard`](https://github.com/bar19y-oss/clickhouse-s3-guard) `1.3.0`, for the S3 guard subchart

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
| [`ingress-route-values.yaml`](examples/ingress-route-values.yaml) | Expose ClickHouse HTTP via Ingress or OpenShift Route |
| [`s3-guard-values.yaml`](examples/s3-guard-values.yaml) | Ceph/S3 quota guard subchart wired to the cluster |

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

### Ingress / OpenShift Route

Expose the operator-created ClickHouse HTTP service (port `8123`) externally. Both target the operator's headless `<release>-clickhouse-headless` Service by default; enable whichever fits your platform. Override the derived target via `clickhouseService.suffix` (default `clickhouse-headless`) or `clickhouseService.name` (full name verbatim); per-resource `ingress.serviceName` / `route.serviceName` win when set.

| Parameter | Type | Default |
|---|---|---|
| `ingress.enabled` | `bool` | `false` |
| `ingress.className` | `string` | `""` (cluster default) |
| `ingress.hosts` | `array` | `[{host: clickhouse.local, paths: [{path: /, pathType: Prefix}]}]` |
| `ingress.servicePort` | `int` | `8123` |
| `ingress.tls` | `array` | `[]` |
| `route.enabled` | `bool` | `false` |
| `route.host` | `string` | `""` (OpenShift auto-generates) |
| `route.targetPort` | `int`/`string` | `8123` |
| `route.tls` | `object` | `{}` (plain HTTP) |
| `route.wildcardPolicy` | `string` | `None` |

Kubernetes Ingress:

```bash
helm install clickhouse ./clickhouse-cluster-helm \
  --set ingress.enabled=true \
  --set ingress.className=nginx \
  --set ingress.hosts[0].host=clickhouse.example.com \
  --set ingress.hosts[0].paths[0].path=/ \
  --set ingress.hosts[0].paths[0].pathType=Prefix
```

OpenShift Route with edge TLS:

```bash
helm install clickhouse ./clickhouse-cluster-helm \
  --set route.enabled=true \
  --set route.host=clickhouse.apps.example.com \
  --set route.tls.termination=edge \
  --set route.tls.insecureEdgeTerminationPolicy=Redirect
```

### S3 guard (Ceph / Thanos)

Optional subchart, [`clickhouse-s3-guard`](https://github.com/bar19y-oss/clickhouse-s3-guard). It polls Ceph quota usage through Thanos and, past a threshold, puts the cluster into a safe state — stops merges, TTL merges and moves, and blocks `INSERT`s with a quota — before the object store fills up and corrupts data. Reads and deletes stay open throughout, and the guard unlocks automatically once space is freed.

It is declared as a dependency with a repository **alias**, so no registry URL is baked into this chart. Add the repo once per environment, then resolve the dependency:

```bash
helm repo add clickhouse-s3-guard <your-private-helm-repo-url>
helm dependency build .
```

**`helm dependency build` is required even with the guard disabled.** Helm refuses to render a chart whose declared dependency is missing from `charts/`, regardless of the `condition` — installing from this source tree without it fails with `found in Chart.yaml, but missing in charts/ directory`. Once resolved, `helm package .` bundles the subchart inside the parent archive, so anyone installing that `.tgz` needs no repo access at all. `charts/` and `Chart.lock` are gitignored: `helm dependency update` rewrites the alias in the lock file to the concrete registry URL, which should not be committed.

Four values must be set by hand when `clickhouse-s3-guard.enabled=true`; rendering fails with an actionable message otherwise. They are not auto-derived because the subchart writes its config into a `ConfigMap` verbatim (no `tpl`), so Helm cannot substitute the release name into them, and because this chart does not know the cluster's name in `system.clusters`. The failure message for `host` prints the correct value for your release, including any `clickhouseService` override.

| Parameter | Type | Default |
|---|---|---|
| `clickhouse-s3-guard.enabled` | `bool` | `false` |
| `clickhouse-s3-guard.image.repository` | `string` | `clickhouse-s3-guard` |
| `clickhouse-s3-guard.config.clickhouse.host` | `string` | `""` **(required)** — `<release>-clickhouse-headless.<namespace>.svc` |
| `clickhouse-s3-guard.config.clickhouse.cluster_name` | `string` | `""` **(required)** — name in `system.clusters` |
| `clickhouse-s3-guard.config.clickhouse.username` | `string` | `default` (needs `CREATE`/`DROP QUOTA` + `SYSTEM` grants) |
| `clickhouse-s3-guard.config.thanos.url` | `string` | `""` **(required)** |
| `clickhouse-s3-guard.config.thanos.account` | `string` | `""` **(required)** — watched Ceph account |
| `clickhouse-s3-guard.config.guard.threshold_pct` | `int` | `90` |
| `clickhouse-s3-guard.config.guard.dry_run` | `bool` | `false` |
| `clickhouse-s3-guard.secret.clickhousePassword` | `string` | `""` |
| `clickhouse-s3-guard.secret.thanosApiKey` | `string` | `""` |
| `clickhouse-s3-guard.secret.existingSecret` | `string` | `""` |

Credentials go into a `Secret` the subchart creates, with the keys `THANOS_API_KEY` and `CLICKHOUSE_PASSWORD`. This chart's own `secrets.defaultUserPassword` `Secret` cannot be reused for it — that one exposes a single `password` key. Set `existingSecret` to a `Secret` carrying both keys to manage them out-of-band instead; `clickhousePassword` must otherwise match `secrets.defaultUserPassword.password`.

Only the values above are surfaced in [`values.yaml`](values.yaml); every other subchart value (actions, excluded users, hysteresis, resources, `serviceMonitor`) can be set under the same key and is merged over the subchart's defaults.

```bash
helm install clickhouse ./clickhouse-cluster-helm -n clickhouse \
  --set clickhouse-s3-guard.enabled=true \
  --set clickhouse-s3-guard.image.repository=registry.internal/clickhouse/clickhouse-s3-guard \
  --set clickhouse-s3-guard.config.clickhouse.host=clickhouse-clickhouse-headless.clickhouse.svc \
  --set clickhouse-s3-guard.config.clickhouse.cluster_name=ch_prod \
  --set clickhouse-s3-guard.config.thanos.url=https://thanos-querier.monitoring.svc:9091 \
  --set clickhouse-s3-guard.config.thanos.account=clickhouse-prod \
  --set clickhouse-s3-guard.secret.clickhousePassword=<password> \
  --set clickhouse-s3-guard.secret.thanosApiKey=<api-key> \
  --set clickhouse-s3-guard.config.guard.dry_run=true
```

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
