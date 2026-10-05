{{/* Expand the name of the chart. */}}
{{- define "demo-service.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Fully qualified app name. */}}
{{- define "demo-service.fullname" -}}
{{- default .Chart.Name .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/* Common labels, including Datadog unified service tagging. */}}
{{- define "demo-service.labels" -}}
app.kubernetes.io/name: {{ include "demo-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
tags.datadoghq.com/service: {{ .Values.datadog.service | quote }}
tags.datadoghq.com/env: {{ .Values.datadog.env | quote }}
tags.datadoghq.com/version: {{ .Values.datadog.version | quote }}
{{- end -}}

{{/* Selector labels (stable across rollouts). */}}
{{- define "demo-service.selectorLabels" -}}
app.kubernetes.io/name: {{ include "demo-service.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
