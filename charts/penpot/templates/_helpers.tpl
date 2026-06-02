{{/*
Expand the name of the chart.
*/}}
{{- define "penpot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "penpot.fullname" -}}
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
{{- define "penpot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "penpot.labels" -}}
helm.sh/chart: {{ include "penpot.chart" . }}
{{ include "penpot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "penpot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "penpot.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "penpot.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "penpot.exporterSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-exporter
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
{{- define "penpot.mcpSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-mcp
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "penpot.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "penpot.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Whether Penpot workloads should adapt their securityContext for OpenShift.
*/}}
{{- define "penpot.openshift.adaptSecurityContext" -}}
{{- $mode := default "auto" .Values.global.compatibility.openshift.adaptSecurityContext -}}
{{- if eq $mode "force" -}}
true
{{- else if eq $mode "disabled" -}}
false
{{- else if or (.Capabilities.APIVersions.Has "route.openshift.io/v1") (.Capabilities.APIVersions.Has "route.openshift.io/v1/Route") -}}
true
{{- else -}}
false
{{- end -}}
{{- end }}

{{/*
Render a pod securityContext, omitting only OpenShift-managed user/group IDs.
Keep fsGroup because stateful workloads may still require it for writable PVCs.
*/}}
{{- define "penpot.podSecurityContext" -}}
{{- $ctx := .ctx -}}
{{- $values := .values -}}
{{- if $values -}}
  {{- $adapt := eq (include "penpot.openshift.adaptSecurityContext" $ctx) "true" -}}
  {{- $render := $values -}}
  {{- if $adapt -}}
    {{- $render = omit $values "runAsGroup" -}}
  {{- end -}}
  {{- if gt (len $render) 0 -}}
{{ toYaml $render }}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Render a container securityContext, omitting OpenShift-managed IDs and
runtime user checks when requested.
*/}}
{{- define "penpot.containerSecurityContext" -}}
{{- $ctx := .ctx -}}
{{- $values := .values -}}
{{- if $values -}}
  {{- $adapt := eq (include "penpot.openshift.adaptSecurityContext" $ctx) "true" -}}
  {{- $render := $values -}}
  {{- if $adapt -}}
    {{- $render = omit $values "runAsUser" "runAsGroup" "runAsNonRoot" -}}
  {{- end -}}
  {{- if gt (len $render) 0 -}}
{{ toYaml $render }}
  {{- end -}}
{{- end -}}
{{- end }}

{{/*
Check if MCP is enabled or not.
*/}}
{{- define "penpot.mcpEnabled" -}}
{{- has "enable-mcp" (splitList " " (default "" .Values.config.flags)) -}}
{{- end -}}
