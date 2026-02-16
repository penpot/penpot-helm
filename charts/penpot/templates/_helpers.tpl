{{/*
Common helpers (name/fullname/labels)
*/}}

{{- define "penpot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "penpot.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}

{{- define "penpot.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" -}}
{{- end -}}

{{- define "penpot.selectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "penpot.labels" -}}
helm.sh/chart: {{ include "penpot.chart" . }}
{{ include "penpot.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "penpot.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.fullname" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "penpot.frontendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.fullname" . }}-frontend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "penpot.exporterSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.fullname" . }}-exporter
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{/*
ServiceAccount name
*/}}
{{- define "penpot.serviceAccountName" -}}
{{- if .Values.serviceAccount.enabled -}}
{{- default (include "penpot.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}


{{/*
Booleans helpers
*/}}
{{- define "penpot.bool" -}}
{{- $v := printf "%v" . -}}
{{- if or (eq $v "true") (eq $v "1") -}}true{{- else -}}false{{- end -}}
{{- end -}}


{{/*
Global flags (new flat flags)
*/}}

{{- define "penpot.postgresqlEnabled" -}}
{{- $g := .Values.global | default dict -}}
{{- /* Backward compat: if key is missing, default true */ -}}
{{- if hasKey $g "postgresqlEnabled" -}}
{{- include "penpot.bool" $g.postgresqlEnabled -}}
{{- else -}}
true
{{- end -}}
{{- end -}}

{{- define "penpot.cnpgEnabled" -}}
{{- $g := .Values.global | default dict -}}
{{- include "penpot.bool" (default false $g.cnpgEnabled) -}}
{{- end -}}

{{- define "penpot.cnpgUseAsPrimary" -}}
{{- $g := .Values.global | default dict -}}
{{- include "penpot.bool" (default false $g.cnpgUseAsPrimary) -}}
{{- end -}}

{{- define "penpot.cnpgSupported" -}}
{{- .Capabilities.APIVersions.Has "postgresql.cnpg.io/v1" -}}
{{- end -}}


{{/*
CNPG selection logic
CNPG is primary when:
- cnpgEnabled=true AND (postgresqlEnabled=false OR cnpgUseAsPrimary=true)

This matches your desired behavior:
1) New CNPG install (postgresqlEnabled=false) -> CNPG host
2) Bitnami only (postgresqlEnabled=true, cnpgEnabled=false) -> Bitnami host
3) Migration mode (both enabled) -> Bitnami host
4) Final cutover (postgresqlEnabled=false + cnpgUseAsPrimary=true) -> CNPG host
*/}}
{{- define "penpot.cnpgIsPrimary" -}}
{{- $cnpgEnabled := eq (include "penpot.cnpgEnabled" .) "true" -}}
{{- $useAsPrimary := eq (include "penpot.cnpgUseAsPrimary" .) "true" -}}
{{- $pgEnabled := eq (include "penpot.postgresqlEnabled" .) "true" -}}
{{- if and $cnpgEnabled (or $useAsPrimary (not $pgEnabled)) -}}true{{- else -}}false{{- end -}}
{{- end -}}


{{/*
PostgreSQL host resolver
*/}}
{{- define "penpot.postgresqlHost" -}}
{{- if .Values.config.postgresql.host -}}
{{- .Values.config.postgresql.host -}}
{{- else if eq (include "penpot.cnpgIsPrimary" .) "true" -}}
{{- printf "%s-cnpg-postgresql-rw" .Release.Name -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end -}}


{{/*
CNPG password helper (reuse existing secret if exists, else use provided password, else generate)
*/}}
{{- define "penpot.cnpgAppPassword" -}}
{{- $existing := lookup "v1" "Secret" .Release.Namespace (printf "%s-cnpg-db-secret" .Release.Name) -}}
{{- if $existing -}}
{{- index $existing.data "password" | b64dec -}}
{{- else if .Values.config.postgresql.password -}}
{{- .Values.config.postgresql.password -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end -}}
