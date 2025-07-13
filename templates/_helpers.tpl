{{/*
Expand the name of the chart.
*/}}
{{- define "core-infra.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "core-infra.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "core-infra.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "core-infra.labels" -}}
helm.sh/chart: {{ include "core-infra.chart" . }}
{{ include "core-infra.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.global.labels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "core-infra.selectorLabels" -}}
app.kubernetes.io/name: {{ include "core-infra.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Database connection helpers
*/}}
{{- define "core-infra.postgres.connectionString" -}}
postgresql://{{ .Values.secrets.database.postgresUsername }}:{{ .Values.secrets.database.postgresPassword }}@postgres:{{ .Values.postgres.service.port }}/{{ .Values.postgres.config.database }}
{{- end }}

{{- define "core-infra.mongodb.connectionString" -}}
mongodb://{{ .Values.secrets.database.mongoUsername }}:{{ .Values.secrets.database.mongoPassword }}@mongodb:{{ .Values.mongodb.service.port }}/{{ .Values.mongodb.config.database }}?authSource=admin&retryWrites=true
{{- end }}

{{- define "core-infra.redis.connectionString" -}}
redis://:{{ .Values.secrets.database.redisPassword }}@redis:{{ .Values.redis.service.port }}/0
{{- end }}