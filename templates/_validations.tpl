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
Run all validations. Include this in every resource template.
*/}}
{{- define "clickhouse-cluster.validate" -}}
{{- include "clickhouse-cluster.validateKeeperRef" . }}
{{- include "clickhouse-cluster.validateKeeperReplicas" . }}
{{- include "clickhouse-cluster.validateLoggerLevel" . }}
{{- end }}
