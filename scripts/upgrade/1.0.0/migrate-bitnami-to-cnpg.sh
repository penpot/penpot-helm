#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# migrate-bitnami-to-cnpg.sh
#
# Migrates Penpot PostgreSQL data from Bitnami subchart to CloudNativePG (CNPG)
# in the same namespace.
#
# By default, it DOES NOT switch Penpot to CNPG automatically.
# It prints the Helm command you should run after verifying the migration.
#
# Optional:
#   --switch   -> also performs the switch (sets cnpg.useAsPrimary=true and disables Bitnami)
# ------------------------------------------------------------------------------

log() { printf '[%(%H:%M:%S)T] %s\n' -1 "$*"; }
err() { printf '[%(%H:%M:%S)T] ERROR: %s\n' -1 "$*" >&2; }

NS="${NS:-penpot}"
RELEASE="${RELEASE:-penpot}"
CHART_DIR="${CHART_DIR:-.}"

# DB defaults (match your values.yaml defaults)
DB_NAME="${DB_NAME:-penpot}"
SRC_USER="${SRC_USER:-penpot}"
TGT_USER="${TGT_USER:-penpot}"

# Services (conventions used in your chart)
SRC_HOST="${SRC_HOST:-${RELEASE}-postgresql}"              # Bitnami service name
TGT_HOST="${TGT_HOST:-${RELEASE}-cnpg-postgresql-rw}"      # CNPG RW service name

# Secrets
CNPG_SECRET_NAME="${CNPG_SECRET_NAME:-${RELEASE}-cnpg-db-secret}"

DO_SWITCH="false"
if [[ "${1:-}" == "--switch" ]]; then
  DO_SWITCH="true"
fi

cleanup_pod() {
  local pod="$1"
  kubectl -n "$NS" delete pod "$pod" --ignore-not-found >/dev/null 2>&1 || true
}

get_secret_key_b64() {
  local secret="$1"
  local key="$2"
  kubectl -n "$NS" get secret "$secret" -o "jsonpath={.data.${key}}" 2>/dev/null || true
}

current_backend_db_uri() {
  # Returns current PENPOT_DATABASE_URI from the backend (if deployment exists)
  if kubectl -n "$NS" get deploy/penpot-backend >/dev/null 2>&1; then
    kubectl -n "$NS" exec -it deploy/penpot-backend -- printenv 2>/dev/null | \
      grep -E '^PENPOT_DATABASE_URI=' | head -n1 | cut -d= -f2- || true
  else
    echo ""
  fi
}

read_password_from_helm_values() {
  # Best-effort fallback: get password from computed values (values-driven installs)
  # This is intentionally simple (no jq dependency).
  # Tries (in order):
  # - config.postgresql.password
  # - postgresql.auth.password
  local out
  out="$(helm get values -n "$NS" "$RELEASE" -a 2>/dev/null || true)"
  if [[ -z "$out" ]]; then
    echo ""
    return 0
  fi

  # Try config.postgresql.password
  local p1
  p1="$(printf '%s\n' "$out" | awk '
    $1=="config:"{inconf=1}
    inconf && $1=="postgresql:"{inpg=1; next}
    inconf && inpg && $1=="password:"{print $2; exit}
  ' | tr -d '"' )"
  if [[ -n "${p1:-}" ]]; then
    echo "$p1"
    return 0
  fi

  # Try postgresql.auth.password (bitnami subchart)
  local p2
  p2="$(printf '%s\n' "$out" | awk '
    $1=="postgresql:"{inpg=1}
    inpg && $1=="auth:"{inauth=1; next}
    inpg && inauth && $1=="password:"{print $2; exit}
  ' | tr -d '"' )"
  if [[ -n "${p2:-}" ]]; then
    echo "$p2"
    return 0
  fi

  echo ""
}

read_bitnami_password() {
  # 1) If SRC_PASS is set in env, prefer it.
  if [[ -n "${SRC_PASS:-}" ]]; then
    echo "$SRC_PASS"
    return 0
  fi

  # 2) Try Bitnami secret keys (varies by chart/config)
  local secret="${RELEASE}-postgresql"

  if kubectl -n "$NS" get secret "$secret" >/dev/null 2>&1; then
    local b64=""
    for k in password postgres-password postgresql-password "postgresql-postgres-password"; do
      b64="$(get_secret_key_b64 "$secret" "$k")"
      if [[ -n "$b64" ]]; then
        echo "$b64" | base64 -d
        return 0
      fi
    done
  fi

  # 3) Fallback: try to read from Helm computed values (values-driven)
  local hv
  hv="$(read_password_from_helm_values)"
  if [[ -n "${hv:-}" ]]; then
    echo "$hv"
    return 0
  fi

  echo ""
}

read_cnpg_credentials() {
  local user pass

  if kubectl -n "$NS" get secret "$CNPG_SECRET_NAME" >/dev/null 2>&1; then
    user="$(kubectl -n "$NS" get secret "$CNPG_SECRET_NAME" -o jsonpath='{.data.username}' 2>/dev/null | base64 -d || true)"
    pass="$(kubectl -n "$NS" get secret "$CNPG_SECRET_NAME" -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)"
  else
    user=""
    pass=""
  fi

  # Fallback to defaults if secret doesn't have them (or secret missing)
  if [[ -z "${user:-}" ]]; then user="$TGT_USER"; fi
  if [[ -z "${pass:-}" ]]; then pass="${TGT_PASS:-penpot}"; fi

  printf '%s\n%s\n' "$user" "$pass"
}

wait_for_endpoints() {
  local svc="$1"
  local tries=60
  local i=0
  while (( i < tries )); do
    local eps
    eps="$(kubectl -n "$NS" get endpoints "$svc" -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || true)"
    if [[ -n "$eps" ]]; then
      return 0
    fi
    sleep 2
    (( i++ ))
  done
  return 1
}

scale_penpot() {
  local replicas="$1"
  kubectl -n "$NS" scale deploy/penpot-backend deploy/penpot-frontend deploy/penpot-exporter --replicas="$replicas" >/dev/null
}

rollout_penpot() {
  kubectl -n "$NS" rollout status deploy/penpot-backend --timeout=180s
  kubectl -n "$NS" rollout status deploy/penpot-frontend --timeout=180s
  kubectl -n "$NS" rollout status deploy/penpot-exporter --timeout=180s
}

main() {
  log "Namespace: $NS"
  log "Release:   $RELEASE"
  log "Source DB: $SRC_HOST/$DB_NAME (Bitnami)"
  log "Target DB: $TGT_HOST/$DB_NAME (CNPG)"

  # Preflight: check current backend DB URI (avoid accidental migration when already pointing to CNPG empty)
  local cur_uri
  cur_uri="$(current_backend_db_uri || true)"
  if [[ -n "${cur_uri:-}" ]]; then
    log "Current backend PENPOT_DATABASE_URI: $cur_uri"
    if echo "$cur_uri" | grep -q "${TGT_HOST}"; then
      err "Backend is currently pointing to CNPG (${TGT_HOST})."
      err "If CNPG is empty, Penpot will look 'broken' until data is migrated."
      err "Recommended migration state BEFORE running this script:"
      err "  - Bitnami enabled and used by Penpot (global.postgresqlEnabled=true)"
      err "  - CNPG deployed but NOT primary (global.cnpg.enabled=true, cnpg.useAsPrimary=false)"
      err "Then run this script."
      # Not exiting hard, but strongly warning:
    fi
  else
    log "Could not read current backend DB URI (deployment may not exist yet)."
  fi

  # Ensure CNPG RW service has endpoints (CNPG deployed & ready)
  log "Waiting for CNPG RW service endpoints (${TGT_HOST})..."
  if ! wait_for_endpoints "$TGT_HOST"; then
    err "CNPG RW service '${TGT_HOST}' has no endpoints. Make sure CNPG is deployed and ready."
    err "Example (migration prep, DO NOT switch yet):"
    err "  helm upgrade --install ${RELEASE} ${CHART_DIR} -n ${NS} --create-namespace \\"
    err "    --set global.postgresqlEnabled=true --set global.cnpg.enabled=true --set cnpg.useAsPrimary=false"
    exit 1
  fi

  # Read passwords
  log "Reading source password (Bitnami)..."
  local SRC_PASS_LOCAL
  SRC_PASS_LOCAL="$(read_bitnami_password)"
  if [[ -z "$SRC_PASS_LOCAL" ]]; then
    err "Could not determine Bitnami password."
    err "Provide it explicitly and re-run:"
    err "  SRC_PASS='...' $0"
    exit 1
  fi

  log "Reading target credentials from CNPG secret (${CNPG_SECRET_NAME})..."
  local creds TGT_PASS
  creds="$(read_cnpg_credentials)"
  TGT_USER="$(echo "$creds" | sed -n '1p')"
  TGT_PASS="$(echo "$creds" | sed -n '2p')"

  log "Scaling down Penpot deployments to 0 (avoid writes)..."
  scale_penpot 0

  local POD="pg-migrator-$(date +%Y%m%d-%H%M%S)"
  trap 'log "Cleanup: ensuring Penpot deployments are running..."; scale_penpot 1 >/dev/null 2>&1 || true; cleanup_pod "'"$POD"'"' EXIT

  log "Creating temporary migrator pod ${POD}..."
  kubectl -n "$NS" run "$POD" \
    --image=postgres:16-alpine \
    --restart=Never \
    --env="PGPASSWORD=${SRC_PASS_LOCAL}" \
    --command -- sh -c "sleep 3600" >/dev/null

  kubectl -n "$NS" wait --for=condition=Ready pod/"$POD" --timeout=120s >/dev/null

  log "Running connectivity checks..."
  kubectl -n "$NS" exec "$POD" -- sh -c "pg_isready -h '${SRC_HOST}' -p 5432 -U '${SRC_USER}'" >/dev/null
  kubectl -n "$NS" exec "$POD" -- env "PGPASSWORD=${TGT_PASS}" sh -c "pg_isready -h '${TGT_HOST}' -p 5432 -U '${TGT_USER}'" >/dev/null

  log "Preparing target schema (DROP/CREATE public)..."
  kubectl -n "$NS" exec "$POD" -- env "PGPASSWORD=${TGT_PASS}" sh -c \
    "psql -h '${TGT_HOST}' -U '${TGT_USER}' -d '${DB_NAME}' -v ON_ERROR_STOP=1 -c \"DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;\""

  log "Dumping from Bitnami -> /tmp/penpot.dump ..."
  kubectl -n "$NS" exec "$POD" -- sh -c \
    "pg_dump -Fc -h '${SRC_HOST}' -U '${SRC_USER}' -d '${DB_NAME}' -f /tmp/penpot.dump"

  log "Restoring into CNPG (full restore, schema recreated; no --clean needed)..."
  kubectl -n "$NS" exec "$POD" -- env "PGPASSWORD=${TGT_PASS}" sh -c \
    "pg_restore -h '${TGT_HOST}' -U '${TGT_USER}' -d '${DB_NAME}' --no-owner --no-privileges --exit-on-error /tmp/penpot.dump"

  log "Quick verification (profiles count + sample email)..."
  kubectl -n "$NS" exec "$POD" -- env "PGPASSWORD=${TGT_PASS}" sh -c \
    "psql -h '${TGT_HOST}' -U '${TGT_USER}' -d '${DB_NAME}' -c \"select count(*) as profiles from profile;\""
  kubectl -n "$NS" exec "$POD" -- env "PGPASSWORD=${TGT_PASS}" sh -c \
    "psql -h '${TGT_HOST}' -U '${TGT_USER}' -d '${DB_NAME}' -c \"select email from profile limit 5;\""

  log "Deleting migrator pod ${POD}..."
  cleanup_pod "$POD"

  log "Scaling up Penpot deployments to 1..."
  scale_penpot 1
  rollout_penpot || true

  log "Migration completed (data copied Bitnami -> CNPG)."

  if [[ "$DO_SWITCH" == "true" ]]; then
    log "Switching Penpot to CNPG (cnpg.useAsPrimary=true) and disabling Bitnami..."
    helm upgrade --install "$RELEASE" "$CHART_DIR" -n "$NS" \
      --set global.cnpg.enabled=true \
      --set global.cnpg.useAsPrimary=true \
      --set global.postgresqlEnabled=false
    log "Done. Penpot should now use CNPG."
  else
    echo
    echo "--------------------------------------------------------------------------------"
    echo "NEXT STEP (manual switch AFTER you verify CNPG data):"
    echo
    echo "  helm upgrade --install ${RELEASE} ${CHART_DIR} -n ${NS} \\"
    echo "    --set global.cnpg.enabled=true \\"
    echo "    --set global.cnpg.useAsPrimary=true \\"
    echo "    --set global.postgresqlEnabled=false \\"
    echo "    --set global.valkeyEnabled=true"
    echo
    echo "Tip: before switching, verify CNPG contains what you expect:"
    echo "  kubectl -n ${NS} run -it --rm psql-tgt --image=postgres:16-alpine --restart=Never \\"
    echo "    --env=\"PGPASSWORD=<CNPG_PASSWORD>\" -- sh -c \\"
    echo "    'psql -h ${TGT_HOST} -U ${TGT_USER} -d ${DB_NAME} -c \"select email from profile;\"'"
    echo "--------------------------------------------------------------------------------"
    echo
  fi
}

main "$@"

