# Upgrade Guide

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
