#!/usr/bin/env bash
set -euo pipefail

# ----------------------------
# migrate-bitnami-to-cnpg.sh
# ----------------------------
# Full, repeatable migration:
# - Scales down Penpot (avoid writes)
# - CLEANS CNPG (DROP SCHEMA public CASCADE)
# - Dumps from Bitnami and restores into CNPG (single temp client pod)
# - Switches Penpot to CNPG and disables Bitnami Postgres (Helm upgrade)
# - Always scales Penpot back up (trap)

# ----------------------------
# Config (override via env)
# ----------------------------
NS="${NS:-penpot}"
RELEASE="${RELEASE:-penpot}"
CHART_DIR="/home/fsantiago/Documents/github/penpot-helm/charts/penpot/"

# Source (Bitnami)
SRC_HOST="${SRC_HOST:-penpot-postgresql}"
SRC_USER="${SRC_USER:-penpot}"
SRC_DB="${SRC_DB:-penpot}"

# Target (CNPG)
TGT_HOST="${TGT_HOST:-penpot-cnpg-postgresql-rw}"
TGT_USER="${TGT_USER:-penpot}"
TGT_DB="${TGT_DB:-penpot}"

# Deployments to scale
DEPLOYS=(penpot-backend penpot-frontend penpot-exporter)

timestamp() { date +"[%H:%M:%S]"; }
log() { echo "$(timestamp) $*"; }

# ----------------------------
# Scaling helpers
# ----------------------------
scale_down() {
  log "Scaling down Penpot deployments to 0 (avoid writes)..."
  kubectl -n "$NS" scale deploy "${DEPLOYS[@]}" --replicas=0 || true
}

scale_up() {
  log "Scaling up Penpot deployments to 1..."
  kubectl -n "$NS" scale deploy "${DEPLOYS[@]}" --replicas=1 || true
  kubectl -n "$NS" rollout status deploy/penpot-backend --timeout=5m || true
  kubectl -n "$NS" rollout status deploy/penpot-frontend --timeout=5m || true
  kubectl -n "$NS" rollout status deploy/penpot-exporter --timeout=5m || true
}

cleanup() {
  log "Cleanup: ensuring Penpot deployments are running..."
  scale_up
}
trap cleanup EXIT

# ----------------------------
# Secrets helpers (adjust if your secret keys differ)
# ----------------------------
read_src_pass() {
  kubectl -n "$NS" get secret penpot-postgresql -o jsonpath='{.data.password}' | base64 -d
}

read_tgt_pass() {
  kubectl -n "$NS" get secret "${RELEASE}-cnpg-db-secret" -o jsonpath='{.data.password}' | base64 -d
}

# ----------------------------
# CNPG readiness: RW service must have endpoints
# ----------------------------
wait_cnpg_ready() {
  log "Waiting for CNPG RW service endpoints..."
  for _ in $(seq 1 90); do
    if kubectl -n "$NS" get endpoints "$TGT_HOST" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q '.'; then
      return 0
    fi
    sleep 2
  done
  log "ERROR: CNPG RW service has no endpoints: $TGT_HOST"
  kubectl -n "$NS" get pods -o wide || true
  kubectl -n "$NS" get svc -o wide || true
  exit 1
}

# ----------------------------
# Create a temporary client-only pod (sleep), then exec psql/pg_dump/pg_restore inside it
# ----------------------------
create_client_pod() {
  local pod="$1"
  local src_pass="$2"
  local tgt_pass="$3"

  log "Creating temporary client pod ${pod} (postgres client only)..."
  kubectl -n "$NS" run "$pod" \
    --image=postgres:16-alpine \
    --restart=Never \
    --env="SRC_PASS=${src_pass}" \
    --env="TGT_PASS=${tgt_pass}" \
    --command -- sh -c 'sleep 3600' >/dev/null

  kubectl -n "$NS" wait --for=condition=Ready pod/"$pod" --timeout=120s
}

delete_pod() {
  local pod="$1"
  log "Deleting pod ${pod}..."
  kubectl -n "$NS" delete pod "$pod" --wait=false >/dev/null || true
}

# ----------------------------
# CLEAN CNPG database (DROP/CREATE schema public)
# ----------------------------
clean_cnpg_public_schema() {
  local pod="$1"
  local tgt_pass="$2"

  log "Cleaning CNPG target DB (DROP SCHEMA public CASCADE; CREATE SCHEMA public;)..."
  kubectl -n "$NS" exec -i "$pod" -- sh -c \
    "export PGPASSWORD=\"${tgt_pass}\"; psql -h ${TGT_HOST} -U ${TGT_USER} -d ${TGT_DB} -v ON_ERROR_STOP=1 -c \"DROP SCHEMA IF EXISTS public CASCADE; CREATE SCHEMA public;\""
}

# ----------------------------
# Dump + restore (full)
# ----------------------------
dump_from_bitnami() {
  local pod="$1"
  local src_pass="$2"
  local dump="$3"

  log "Dumping from Bitnami -> ${dump} ..."
  kubectl -n "$NS" exec -i "$pod" -- sh -c \
    "export PGPASSWORD=\"${src_pass}\"; pg_dump -h ${SRC_HOST} -U ${SRC_USER} -d ${SRC_DB} -Fc -f ${dump}"
}

restore_into_cnpg() {
  local pod="$1"
  local tgt_pass="$2"
  local dump="$3"

  log "Restoring into CNPG (full restore, NO --clean)..."
  kubectl -n "$NS" exec -i "$pod" -- sh -c \
    "export PGPASSWORD=\"${tgt_pass}\"; pg_restore -h ${TGT_HOST} -U ${TGT_USER} -d ${TGT_DB} --no-owner --no-privileges ${dump}"
}

# ----------------------------
# Switch Penpot to CNPG and disable Bitnami Postgres
# ----------------------------
switch_penpot_to_cnpg_and_disable_bitnami() {
  log "Switching Penpot to CNPG and disabling Bitnami Postgres (Helm upgrade)..."
  helm upgrade --install "$RELEASE" "$CHART_DIR" -n "$NS" \
    --set global.postgresqlEnabled=false \
    --set config.postgresql.host="$TGT_HOST" \
    --set migration.enabled=true \
    --set global.valkeyEnabled=true
}

# ----------------------------
# Main
# ----------------------------
main() {
  wait_cnpg_ready

  local src_pass tgt_pass
  src_pass="$(read_src_pass)"
  tgt_pass="$(read_tgt_pass)"

  scale_down

  local pod="pg-migrator-$(date +%Y%m%d-%H%M%S)"
  local dump="/tmp/penpot.dump"

  create_client_pod "$pod" "$src_pass" "$tgt_pass"

  # Clean CNPG before restoring (this is the key change you asked for)
  clean_cnpg_public_schema "$pod" "$tgt_pass"

  # Dump + restore
  dump_from_bitnami "$pod" "$src_pass" "$dump"
  restore_into_cnpg "$pod" "$tgt_pass" "$dump"

  delete_pod "$pod"

  # Switch Penpot to CNPG, disable Bitnami
  switch_penpot_to_cnpg_and_disable_bitnami

  log "Done."
}

main "$@"

