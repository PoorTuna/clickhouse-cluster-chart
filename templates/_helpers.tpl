{{/*
Expand the name of the chart.
*/}}
{{- define "clickhouse-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this
(by the DNS naming spec). If release name contains chart name it will be used as
a full name.
*/}}
{{- define "clickhouse-cluster.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create the name for the KeeperCluster resource.
*/}}
{{- define "clickhouse-cluster.keeperFullname" -}}
{{- if .Values.keeperFullnameOverride }}
{{- .Values.keeperFullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Resolve the KeeperCluster reference name. If keeperCluster is enabled and
the user has not specified a name, auto-derive from the release.
*/}}
{{- define "clickhouse-cluster.keeperRef" -}}
{{- if .Values.clickhouseCluster.keeperClusterRef.name }}
{{- .Values.clickhouseCluster.keeperClusterRef.name }}
{{- else }}
{{- include "clickhouse-cluster.keeperFullname" . }}
{{- end }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "clickhouse-cluster.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels applied to every resource.
*/}}
{{- define "clickhouse-cluster.labels" -}}
helm.sh/chart: {{ include "clickhouse-cluster.chart" . }}
{{ include "clickhouse-cluster.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels for ClickHouse pods.
*/}}
{{- define "clickhouse-cluster.selectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector labels for Keeper pods.
*/}}
{{- define "clickhouse-cluster.keeperSelectorLabels" -}}
app.kubernetes.io/name: {{ include "clickhouse-cluster.name" . }}-keeper
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Render annotations by merging common + extra annotations, omitting if both empty.
Usage: {{ include "clickhouse-cluster.renderAnnotations" (dict "common" .Values.commonAnnotations "extra" .extraAnnotations) }}
*/}}
{{- define "clickhouse-cluster.renderAnnotations" -}}
{{- $merged := dict }}
{{- with .common }}{{- $merged = merge $merged . }}{{- end }}
{{- with .extra }}{{- $merged = merge $merged . }}{{- end }}
{{- if $merged }}
{{- toYaml $merged }}
{{- end }}
{{- end }}

{{/*
Auto-derive the Secret name for the default user password.
*/}}
{{- define "clickhouse-cluster.defaultUserPasswordSecretName" -}}
{{- if .Values.secrets.defaultUserPassword.name }}
{{- .Values.secrets.defaultUserPassword.name }}
{{- else }}
{{- printf "%s-default-user-password" (include "clickhouse-cluster.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
Auto-derive the Secret name for TLS.
*/}}
{{- define "clickhouse-cluster.tlsSecretName" -}}
{{- if .Values.secrets.tls.name }}
{{- .Values.secrets.tls.name }}
{{- else }}
{{- printf "%s-tls" (include "clickhouse-cluster.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
