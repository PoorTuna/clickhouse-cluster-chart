# Upgrade Guide

## 0.3.0

Adds [`clickhouse-s3-guard`](https://github.com/bar19y-oss/clickhouse-s3-guard) `1.3.0` as an optional subchart — the chart's first dependency. It watches Ceph/S3 quota usage via Thanos and puts the cluster into a safe state (stop merges/TTL merges/moves, block `INSERT`s by quota, reads and deletes unaffected) before the object store fills up and corrupts data, unlocking again when space is freed.

Declared in `Chart.yaml` with `condition: clickhouse-s3-guard.enabled` and the repository **alias** `@clickhouse-s3-guard` rather than a URL, so no environment-specific registry is baked into the chart. This suits airgapped installs: publish the subchart to your private Helm repo, then run once per environment:

```bash
helm repo add clickhouse-s3-guard <your-private-helm-repo-url>
helm dependency build .
```

Four values are required when the guard is enabled — `config.clickhouse.host`, `config.clickhouse.cluster_name`, `config.thanos.url`, `config.thanos.account` — plus credentials via `secret.clickhousePassword`/`secret.thanosApiKey` or `secret.existingSecret`. The new `clickhouse-cluster.validateS3Guard` rule in `templates/_validations.tpl` fails the render with an actionable message when any is missing, and the `host` message prints the correct Service name for your release (resolved through `clickhouse-cluster.clickhouseServiceName`, so `clickhouseService` overrides are reflected). These cannot be derived automatically: the subchart renders its config into a `ConfigMap` verbatim without `tpl`, so Helm cannot substitute the release name, and this chart does not know the cluster's name in `system.clusters`.

The guard's credentials `Secret` uses the keys `THANOS_API_KEY` and `CLICKHOUSE_PASSWORD`, so this chart's `secrets.defaultUserPassword` `Secret` (single `password` key, release-derived name) cannot be reused for it.

`values.schema.json` gains a deliberately permissive `clickhouse-s3-guard` section — without it the root `"additionalProperties": false` would reject the subchart's values outright, and typing every subchart key would break on each subchart release.

**Action required even if you never enable the guard:** Helm refuses to render a chart whose declared dependency is absent from `charts/`, and it ignores `condition` when making that check, so installing from this source tree now fails with `found in Chart.yaml, but missing in charts/ directory: clickhouse-s3-guard` until `helm dependency build` has been run once. Installing from a `helm package`-produced `.tgz` is unaffected — the subchart is bundled inside it. `charts/` and `Chart.lock` are now gitignored, because `helm dependency update` rewrites the repo alias to the concrete registry URL when it writes the lock file.

Beyond that step, no values changes are required on upgrade — the toggle defaults off, so rendered output for existing releases is unchanged apart from the `helm.sh/chart` version label. See [`examples/s3-guard-values.yaml`](./examples/s3-guard-values.yaml).

## 0.2.10

Adds `additionalServices`, an optional list of extra Services selecting ClickHouse pods directly. Useful for a stable `ClusterIP` — the operator's auto-created headless Service (`<CR>-clickhouse-headless`, `clusterIP: None`) only does DNS round-robin, which can break clients that expect a single stable IP (e.g. some connection poolers/load balancers).

Each entry defaults `type` to `ClusterIP` and, unless `selector` is set, selects `app: <release>-clickhouse` — the label the official ClickHouse operator (`clickhouse.com/v1alpha1`) stamps on its pods, same selector already used by the `ServiceMonitor` and `NetworkPolicy`. Set `selector` per entry to target a different label set.

Empty list by default (`additionalServices: []`), so existing releases are unaffected. See the commented example in `values.yaml`.

## 0.2.9

Fixes the Ingress / Route backend Service name. The `clickhouse-cluster.clickhouseServiceName` helper resolved to `<CR-name>-clickhouse`, but the operator only creates a headless Service named `<CR-name>-clickhouse-headless` (same name the Helm test Pods connect to). Ingress/Route backends pointed at a non-existent Service and never routed traffic. The helper now appends `-headless`.

The derived name is now configurable via the new `clickhouseService` block: set `clickhouseService.suffix` to change the appended suffix (default `clickhouse-headless`), or `clickhouseService.name` to pin the full Service name verbatim. Setting both `name` and a non-default `suffix` is a templating error (mutually exclusive). Per-resource `ingress.serviceName` / `route.serviceName` still take precedence when set.

No values changes required for the default behavior.

## 0.2.8

Adds optional external exposure of the ClickHouse HTTP interface (port `8123`) via a Kubernetes `Ingress` and/or an OpenShift `Route`.

Both target the operator-created load-balanced Service `<CR-name>-clickhouse` (resolved by the new `clickhouse-cluster.clickhouseServiceName` helper). The backend Service name and port are overridable via `ingress.serviceName` / `ingress.servicePort` and `route.serviceName` / `route.targetPort` for non-default operator setups.

- `templates/ingress.yaml` — `networking.k8s.io/v1` Ingress, gated on `ingress.enabled` (default `false`). Configurable `className`, `hosts[]` (host + paths with `pathType`), and `tls[]`.
- `templates/route.yaml` — `route.openshift.io/v1` Route, gated on `route.enabled` (default `false`). Configurable `host`, `tls` termination block, and `wildcardPolicy`. Plain HTTP when `tls` is empty.

Both resources carry the `app.kubernetes.io/component: clickhouse` label and merge `commonAnnotations`. No values changes required on upgrade — both toggles default off, so existing releases are unaffected. Enable whichever matches your platform; see [`examples/ingress-route-values.yaml`](./examples/ingress-route-values.yaml).

## 0.2.7

Ships a supplemental headless Service so the keeper `ServiceMonitor` can actually find a target.

The official ClickHouse operator's Keeper pod exposes Prometheus metrics on port `9090` (container port name `prometheus`, path `/metrics`, injected via a hardcoded top-level `<prometheus>` config block — see `internal/controller/keeper/templates.go`). However, the operator's generated headless Service (`<CR>-keeper-headless`) only opens `raft-ipc` (9234), `keeper` (2181), and optionally `keeper-secure` (2281). Port 9090 is **not** on that Service.

A `ServiceMonitor` selects by Service port, so in 0.2.6 and earlier the keeper ServiceMonitor targeted a port that no Service exposed — it produced zero targets. This release adds a chart-owned headless Service `<keeperObjectName>-metrics` that selects the operator's keeper Pods (`app: <CR>-keeper`) and publishes port `prometheus`/9090 via `targetPort: prometheus`. `publishNotReadyAddresses: true` so scrapes keep flowing during rollouts.

The keeper ServiceMonitor template is unchanged — its default `matchLabels: app: <CR>-keeper` selector matches both the operator's headless Service and the new one, but only the new one carries a `prometheus` port so only it contributes endpoints. No duplicate scrapes.

The Service is gated on the same `keeperServiceMonitor.enabled` toggle as the ServiceMonitor, so they travel together.

## 0.2.6

The default `cluster` label stamp moved from `relabelings` (target-level) to `metricRelabelings` (per-metric, applied at ingestion).

In 0.2.5 the `cluster` label was added via target relabeling, but in practice several Prometheus operator setups don't propagate custom target labels to scraped metrics — the label appeared on `/targets` but was absent from the time series. `metricRelabelings` runs per-metric immediately before ingestion and reliably stamps `cluster=<CR-name>` on every series.

User-supplied `.Values.serviceMonitor.metricRelabelings` / `.Values.keeperServiceMonitor.metricRelabelings` still apply and are appended after the default entry.

## 0.2.5

Both ServiceMonitors now stamp a `cluster` label on every scraped series.

- ClickHouse metrics: `cluster=<CR-name>` (from `clickhouse-cluster.fullname`).
- Keeper metrics: `cluster=<CR-name>` (from `clickhouse-cluster.keeperFullname`).

This is needed because the bundled Grafana dashboard and PrometheusRule both query metrics with `{cluster="<CR-name>"}` — without the label, queries returned empty. Implemented as a default `relabelings` entry in each ServiceMonitor, prepended before any user-supplied `serviceMonitor.relabelings` / `keeperServiceMonitor.relabelings`. Users who want to override can still set their own relabelings; the default `cluster` stamp will remain unless they explicitly drop it.

## 0.2.4

Fixes the `NetworkPolicy` `podSelector` label mismatch flagged as a known issue in 0.2.3.

- All `podSelector.matchLabels` pairs across both NetworkPolicies now use `app: <CR-name>-clickhouse` / `app: <CR-name>-keeper` — the same label the operator puts on Pods. The previous `app.kubernetes.io/instance` + `app.kubernetes.io/component` matchers matched zero Pods, so NetworkPolicies were no-ops.

If you previously had `networkPolicy.enabled: true` and were expecting traffic to be constrained, note that in 0.2.3 and earlier the policies silently allowed everything because nothing matched. Re-validate your connectivity model on upgrade.

## 0.2.3

Fixes ServiceMonitor selectors and test-Pod hostnames to match the labels and Service names the official ClickHouse operator actually creates.

- ServiceMonitor `selector.matchLabels` changed to `app: <CR-name>-clickhouse` and `app: <CR-name>-keeper`. The previous `app.kubernetes.io/instance` + `app.kubernetes.io/component` pair matched zero Services because the operator's headless Services only carry the `app` label. ServiceMonitors were effectively no-ops before this fix.
- Test Pod hosts now point at the real headless Service DNS names: `<CR-name>-clickhouse-headless` for the ClickHouse tests and `<CR-name>-keeper-headless` for the Keeper test. Previously the hosts resolved to non-existent Services and the Helm tests would fail.

Known remaining issue (not fixed in this release): NetworkPolicy `podSelector.matchLabels` still uses the old `app.kubernetes.io/instance` + `app.kubernetes.io/component` labels, which don't match what the operator puts on Pods — the policies match zero Pods today and are no-ops. If you rely on NetworkPolicies, leave them disabled until this is fixed in a follow-up.

## 0.2.2

Fixes two CRD-schema mismatches that caused server-side apply to reject both CRs.

- `spec.containerTemplate.imagePullPolicy` is now emitted as a sibling of `image` (previously nested under `image.imagePullPolicy`, which is not a valid field on the `ContainerImage` type). Applies to both `ClickHouseCluster` and `KeeperCluster`.
- `spec.settings.tls.serverCertSecret.key` is no longer emitted — the CRD's `serverCertSecret` is a `LocalObjectReference` (name-only); the operator hardcodes the cert-manager layout (`tls.crt` / `tls.key`). The matching `key` field has been removed from `values.yaml`, `values.schema.json`, and `examples/production-values.yaml`. The `caBundle` field still accepts `key` (it's a `SecretKeySelector`) — unchanged.

Users who previously set `clickhouseCluster.settings.tls.serverCertSecret.key` or `keeperCluster.settings.tls.serverCertSecret.key` in their values should remove it; the schema now rejects it.

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
