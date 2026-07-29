{{/*
Validation: if ClickHouseCluster is enabled but no keeper is available, fail.
*/}}
{{- define "clickhouse-cluster.validateKeeperRef" -}}
{{- if .Values.clickhouseCluster.enabled }}
  {{- if and (not .Values.keeperCluster.enabled) (not .Values.clickhouseCluster.keeperClusterRef.name) }}
    {{- fail "clickhouseCluster requires a keeper: either enable keeperCluster.enabled or set clickhouseCluster.keeperClusterRef.name" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Validation: keeper replicas must be an odd number from the allowed set.
*/}}
{{- define "clickhouse-cluster.validateKeeperReplicas" -}}
{{- if .Values.keeperCluster.enabled }}
  {{- $allowed := list 0 1 3 5 7 9 11 13 15 }}
  {{- if not (has (int .Values.keeperCluster.replicas) $allowed) }}
    {{- fail (printf "keeperCluster.replicas must be one of %v, got: %v" $allowed (int .Values.keeperCluster.replicas)) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Validation: logger level must be a valid enum value.
*/}}
{{- define "clickhouse-cluster.validateLoggerLevel" -}}
{{- $allowed := list "test" "trace" "debug" "information" "notice" "warning" "error" "critical" "fatal" }}
{{- if .Values.clickhouseCluster.enabled }}
  {{- if not (has .Values.clickhouseCluster.settings.logger.level $allowed) }}
    {{- fail (printf "clickhouseCluster.settings.logger.level must be one of %v, got: %s" $allowed .Values.clickhouseCluster.settings.logger.level) }}
  {{- end }}
{{- end }}
{{- if .Values.keeperCluster.enabled }}
  {{- if not (has .Values.keeperCluster.settings.logger.level $allowed) }}
    {{- fail (printf "keeperCluster.settings.logger.level must be one of %v, got: %s" $allowed .Values.keeperCluster.settings.logger.level) }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Validation: the clickhouse-s3-guard subchart renders its config verbatim into a
ConfigMap (no tpl), so values that depend on the release name cannot be derived
for it. Fail early with the exact value to use instead of letting the guard run
against the subchart's placeholder defaults.
*/}}
{{- define "clickhouse-cluster.validateS3Guard" -}}
{{- $guard := index .Values "clickhouse-s3-guard" | default dict }}
{{- if $guard.enabled }}
  {{- $config := $guard.config | default dict }}
  {{- $ch := $config.clickhouse | default dict }}
  {{- if not $ch.host }}
    {{- fail (printf "clickhouse-s3-guard.config.clickhouse.host must point at this cluster's ClickHouse Service, set it to: %s.%s.svc" (include "clickhouse-cluster.clickhouseServiceName" .) .Release.Namespace) }}
  {{- end }}
  {{- if not $ch.cluster_name }}
    {{- fail "clickhouse-s3-guard.config.clickhouse.cluster_name must be set to the cluster name as it appears in system.clusters (used for ON CLUSTER statements)" }}
  {{- end }}
  {{- $thanos := $config.thanos | default dict }}
  {{- if not $thanos.url }}
    {{- fail "clickhouse-s3-guard.config.thanos.url must be set to the Thanos Querier endpoint" }}
  {{- end }}
  {{- if not $thanos.account }}
    {{- fail "clickhouse-s3-guard.config.thanos.account must be set to the Ceph account whose quota is watched" }}
  {{- end }}
  {{- $secret := $guard.secret | default dict }}
  {{- if and (not $secret.existingSecret) (not $secret.clickhousePassword) }}
    {{- fail "clickhouse-s3-guard: set secret.clickhousePassword, or secret.existingSecret naming a Secret with keys THANOS_API_KEY and CLICKHOUSE_PASSWORD" }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Run all validations. Include this in every resource template.
*/}}
{{- define "clickhouse-cluster.validate" -}}
{{- include "clickhouse-cluster.validateKeeperRef" . }}
{{- include "clickhouse-cluster.validateKeeperReplicas" . }}
{{- include "clickhouse-cluster.validateLoggerLevel" . }}
{{- include "clickhouse-cluster.validateS3Guard" . }}
{{- end }}
