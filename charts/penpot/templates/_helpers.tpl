{{/*
Expand the name of the chart.
*/}}
{{- define "penpot.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
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
{{- end }}
{{- define "penpot.backendSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-backend
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
{{- define "penpot.exporterSelectorLabels" -}}
app.kubernetes.io/name: {{ include "penpot.name" . }}-exporter
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

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
Resolve the PostgreSQL host to use.

Behavior:
- Bitnami PostgreSQL is used when global.postgresqlEnabled=true
- CNPG is ONLY used when:
  - global.cnpg.enabled=true
  - global.cnpg.useAsPrimary=true
  - global.postgresqlEnabled=false
*/}}
{{- define "penpot.postgresqlHost" -}}
{{- $global := .Values.global | default dict -}}
{{- $cnpg := $global.cnpg | default dict -}}

{{- $cnpgEnabledRaw := default false $cnpg.enabled -}}
{{- $cnpgUseAsPrimaryRaw := default false $cnpg.useAsPrimary -}}
{{- $postgresqlEnabledRaw := ternary $global.postgresqlEnabled true (hasKey $global "postgresqlEnabled") -}}

{{- $cnpgEnabled := eq (include "penpot.bool" $cnpgEnabledRaw) "true" -}}
{{- $cnpgUseAsPrimary := eq (include "penpot.bool" $cnpgUseAsPrimaryRaw) "true" -}}
{{- $postgresqlEnabled := eq (include "penpot.bool" $postgresqlEnabledRaw) "true" -}}

{{- if .Values.config.postgresql.host -}}
{{- .Values.config.postgresql.host -}}
{{- else if and $cnpgEnabled $cnpgUseAsPrimary (not $postgresqlEnabled) -}}
{{- printf "%s-cnpg-postgresql-rw" .Release.Name -}}
{{- else -}}
{{- printf "%s-postgresql" .Release.Name -}}
{{- end -}}
{{- end }}

{{/*
Return CNPG app password:
- If secret exists, reuse it
- Else use config.postgresql.password if set
- Else generate one
*/}}
{{- define "penpot.cnpgAppPassword" -}}
{{- $ns := .Release.Namespace -}}
{{- $name := printf "%s-cnpg-db-secret" .Release.Name -}}
{{- $existing := lookup "v1" "Secret" $ns $name -}}
{{- if $existing -}}
{{- index $existing.data "password" | b64dec -}}
{{- else if .Values.config.postgresql.password -}}
{{- .Values.config.postgresql.password -}}
{{- else -}}
{{- randAlphaNum 32 -}}
{{- end -}}
{{- end }}

{{/*
Return the secret name used for DB credentials
*/}}
{{- define "penpot.postgresqlSecretName" -}}
{{- $global := .Values.global | default dict -}}
{{- $cnpg := $global.cnpg | default dict -}}

{{- $cnpgEnabledRaw := default false $cnpg.enabled -}}
{{- $cnpgUseAsPrimaryRaw := default false $cnpg.useAsPrimary -}}
{{- $postgresqlEnabledRaw := ternary $global.postgresqlEnabled true (hasKey $global "postgresqlEnabled") -}}

{{- $cnpgEnabled := eq (include "penpot.bool" $cnpgEnabledRaw) "true" -}}
{{- $cnpgUseAsPrimary := eq (include "penpot.bool" $cnpgUseAsPrimaryRaw) "true" -}}
{{- $postgresqlEnabled := eq (include "penpot.bool" $postgresqlEnabledRaw) "true" -}}

{{- $cnpgPrimary := and $cnpgEnabled $cnpgUseAsPrimary (not $postgresqlEnabled) -}}

{{- if .Values.config.postgresql.existingSecret -}}
{{- .Values.config.postgresql.existingSecret -}}
{{- else if $cnpgPrimary -}}
{{- printf "%s-cnpg-db-secret" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end }}

{{/*
Coerce a value to boolean.
Accepts: true/false, "true"/"false", "1"/"0", 1/0
*/}}
{{- define "penpot.bool" -}}
{{- $v := printf "%v" . -}}
{{- if or (eq $v "true") (eq $v "1") -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}
