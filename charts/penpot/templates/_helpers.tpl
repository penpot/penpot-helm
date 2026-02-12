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

{{/* --------------------------------------------------------------------- */}}
{{/* ------------------------ CNPG / PostgreSQL helpers ------------------- */}}
{{/* --------------------------------------------------------------------- */}}

{{/*
Coerce a value to boolean string: "true" or "false"
Accepts: true/false, "true"/"false", "1"/"0", 1/0
*/}}
{{- define "penpot.bool" -}}
{{- $v := printf "%v" . -}}
{{- if or (eq $v "true") (eq $v "1") -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
Return "true" if global.postgresqlEnabled was explicitly set by the user (in values or via --set).
*/}}
{{- define "penpot.pgEnabledIsSet" -}}
{{- $g := .Values.global | default dict -}}
{{- if hasKey $g "postgresqlEnabled" -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
Return pgEnabled as boolean string ("true"/"false").
Default is "true" ONLY when not explicitly set (backward compatible).
*/}}
{{- define "penpot.pgEnabled" -}}
{{- $g := .Values.global | default dict -}}
{{- if hasKey $g "postgresqlEnabled" -}}
{{- include "penpot.bool" $g.postgresqlEnabled -}}
{{- else -}}
true
{{- end -}}
{{- end -}}

{{/*
Detect whether Bitnami PostgreSQL exists in the cluster (installed already).
*/}}
{{- define "penpot.bitnamiPresent" -}}
{{- $ns := .Release.Namespace -}}
{{- $name := printf "%s-postgresql" .Release.Name -}}
{{- $sts := lookup "apps/v1" "StatefulSet" $ns $name -}}
{{- if $sts -}}true{{- else -}}false{{- end -}}
{{- end -}}

{{/*
CNPG is primary if:
- CNPG enabled AND
- (
    useAsPrimary=true (explicit switch), OR
    (postgresqlEnabled is NOT explicitly set AND Bitnami is NOT present)  -> new install CNPG
  )
AND postgresqlEnabled is NOT explicitly true.

This matches your scenarios:
1) new install: cnpg.enabled=true, pg not set, bitnami not present -> CNPG primary
2) bitnami only: postgresqlEnabled=true -> Bitnami primary
3) migration mode: cnpg.enabled=true + postgresqlEnabled=true -> Bitnami primary
4) switch: cnpg.enabled=true + cnpg.useAsPrimary=true + postgresqlEnabled=false -> CNPG primary
*/}}
{{- define "penpot.cnpgIsPrimary" -}}
{{- $g := .Values.global | default dict -}}
{{- $cnpg := $g.cnpg | default dict -}}

{{- $cnpgEnabled := eq (include "penpot.bool" (default false $cnpg.enabled)) "true" -}}
{{- $useAsPrimary := eq (include "penpot.bool" (default false $cnpg.useAsPrimary)) "true" -}}

{{- $pgEnabled := eq (include "penpot.pgEnabled" .) "true" -}}
{{- $pgIsSet := eq (include "penpot.pgEnabledIsSet" .) "true" -}}
{{- $bitnamiPresent := eq (include "penpot.bitnamiPresent" .) "true" -}}

{{- if and $cnpgEnabled (not $pgEnabled) -}}
true
{{- else if and $cnpgEnabled $useAsPrimary (not $pgEnabled) -}}
true
{{- else if and $cnpgEnabled (not $pgIsSet) (not $bitnamiPresent) -}}
true
{{- else -}}
false
{{- end -}}
{{- end -}}

{{/*
Resolve the PostgreSQL host to use.
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
Return the secret name used for DB credentials.
*/}}
{{- define "penpot.postgresqlSecretName" -}}
{{- if .Values.config.postgresql.existingSecret -}}
{{- .Values.config.postgresql.existingSecret -}}
{{- else if eq (include "penpot.cnpgIsPrimary" .) "true" -}}
{{- printf "%s-cnpg-db-secret" .Release.Name -}}
{{- else -}}
{{- "" -}}
{{- end -}}
{{- end -}}

{{/*
Return CNPG app password:
- If secret exists, reuse it (avoid regen on upgrade)
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
{{- end -}}
{{/*
Return true if configuration is invalid:
- Bitnami PostgreSQL enabled AND
- CNPG useAsPrimary enabled
*/}}
{{- define "penpot.invalidConfig" -}}
{{- $pgEnabled := eq (include "penpot.pgEnabled" .) "true" -}}
{{- $g := .Values.global | default dict -}}
{{- $cnpg := $g.cnpg | default dict -}}
{{- $useAsPrimary := eq (include "penpot.bool" (default false $cnpg.useAsPrimary)) "true" -}}
{{- if and $pgEnabled $useAsPrimary -}}true{{- else -}}false{{- end -}}
{{- end -}}
