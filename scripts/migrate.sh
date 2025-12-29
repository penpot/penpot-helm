#!/usr/bin/env bash
set -euo pipefail

# =========================
# Config
# =========================
# Source and target namespaces
# These are example values and should be adapted to your environment

NS_SRC="penpot"
NS_DST="penpot-migration"

APPS=("penpot-backend" "penpot-frontend" "penpot-exporter")

TS="$(date +%Y%m%d-%H%M%S)"
DUMP_FILE="penpot-db-${TS}.dump"

# SOURCE (Bitnami legacy)
SRC_HOST="penpot-postgresql"
SRC_PORT="5432"
SRC_SECRET="penpot-postgresql"
SRC_DB="penpot"
SRC_USER="penpot"

# TARGET (CNPG)
DST_HOST="penpot-postgresql-rw"
DST_PORT="5432"
DST_SECRET="penpot-db-secret"   # keys: username/password
DST_DB="penpot"

# =========================
# Helpers
# =========================
log(){ echo "[$(date +%H:%M:%S)] $*"; }

b64d_py(){ python3 -c 'import base64,sys; print(base64.b64decode(sys.stdin.read().strip()).decode())'; }

scale_apps() {
  local ns="$1" replicas="$2"
  for d in "${APPS[@]}"; do
    if kubectl -n "$ns" get deploy "$d" >/dev/null 2>&1; then
      kubectl -n "$ns" scale deploy "$d" --replicas="$replicas" >/dev/null
    fi
  done
}

get_secret_key_decoded() {
  local ns="$1" secret="$2" key="$3"
  local b64=""
  b64="$(kubectl -n "$ns" get secret "$secret" -o json 2>/dev/null \
    | python3 -c "import json,sys; obj=json.load(sys.stdin); print(obj.get('data', {}).get('${key}',''))" \
    || true)"
  [[ -n "$b64" ]] || return 1
  printf "%s" "$b64" | b64d_py
}

get_src_pass() {
  local pass=""
  pass="$(get_secret_key_decoded "$NS_SRC" "$SRC_SECRET" "password" || true)"
  [[ -z "$pass" ]] && pass="$(get_secret_key_decoded "$NS_SRC" "$SRC_SECRET" "postgres-password" || true)"
  [[ -n "$pass" ]] || { echo "ERROR: Cannot read source password from ${NS_SRC}/${SRC_SECRET}" >&2; exit 1; }
  echo "$pass"
}

get_dst_creds() {
  local user pass
  user="$(get_secret_key_decoded "$NS_DST" "$DST_SECRET" "username" || true)"
  pass="$(get_secret_key_decoded "$NS_DST" "$DST_SECRET" "password" || true)"
  [[ -n "$user" && -n "$pass" ]] || { echo "ERROR: Cannot read target username/password from ${NS_DST}/${DST_SECRET}" >&2; exit 1; }
  echo "$user" "$pass"
}

# kubectl --rm in your env requires -i; keep it.
run_pg_cmd() {
  local ns="$1"; shift
  kubectl run -n "$ns" pg-client --rm -i --restart=Never \
    --image=postgres:16 \
    --env="PGSSLMODE=prefer" \
    --command -- "$@"
}

dump_db() {
  local ns="$1" host="$2" port="$3" user="$4" pass="$5" db="$6"
  log "Dumping DB from ${ns} (${host}:${port}/${db}) -> ${DUMP_FILE}"
  run_pg_cmd "$ns" bash -lc \
    "export PGPASSWORD='${pass}'; pg_dump -h '${host}' -p '${port}' -U '${user}' -d '${db}' -Fc" \
    > "${DUMP_FILE}"
  log "Dump saved locally: ${DUMP_FILE} ($(du -h "${DUMP_FILE}" | awk '{print $1}'))"
}

reset_target_db_schema() {
  local ns="$1" host="$2" port="$3" user="$4" pass="$5" db="$6"
  log "Resetting target schema on ${ns} (${host}:${port}/${db}): DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
  run_pg_cmd "$ns" bash -lc "
    export PGPASSWORD='${pass}';
    psql -h '${host}' -p '${port}' -U '${user}' -d '${db}' -v ON_ERROR_STOP=1 <<SQL
      DROP SCHEMA IF EXISTS public CASCADE;
      CREATE SCHEMA public;
      GRANT ALL ON SCHEMA public TO ${user};
SQL
  " >/dev/null
}

restore_db_via_cp() {
  local ns="$1" host="$2" port="$3" user="$4" pass="$5" db="$6"

  log "Restoring DB into ${ns} (${host}:${port}/${db}) using kubectl cp (robust)"
  kubectl -n "$ns" delete pod pg-client --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "$ns" run pg-client --restart=Never --image=postgres:16 -- sleep 3600 >/dev/null
  kubectl -n "$ns" wait --for=condition=Ready pod/pg-client --timeout=180s >/dev/null

  kubectl -n "$ns" cp "${DUMP_FILE}" "pg-client:/tmp/${DUMP_FILE}" >/dev/null

  kubectl -n "$ns" exec pg-client -- bash -lc \
    "export PGPASSWORD='${pass}'; pg_restore -h '${host}' -p '${port}' -U '${user}' -d '${db}' --no-owner --no-privileges /tmp/${DUMP_FILE}"

  kubectl -n "$ns" delete pod pg-client --ignore-not-found >/dev/null 2>&1 || true
  log "Restore finished."
}

# =========================
# Assets detection + migration (FS storage)
# =========================

get_assets_fsdir() {
  local ns="$1" deploy="$2"
  local fsdir=""
  fsdir="$(kubectl -n "$ns" get deploy "$deploy" -o json 2>/dev/null \
    | python3 -c 'import json,sys; obj=json.load(sys.stdin); c=obj["spec"]["template"]["spec"]["containers"][0];
for e in (c.get("env") or []):
  if e.get("name")=="PENPOT_OBJECTS_STORAGE_FS_DIRECTORY":
    print(e.get("value","")); raise SystemExit
print("")' || true)"
  [[ -n "$fsdir" ]] || fsdir="/opt/data/assets"
  echo "$fsdir"
}

detect_assets_pvc_and_mount() {
  local ns="$1" deploy="${2:-penpot-backend}"

  kubectl -n "$ns" get deploy "$deploy" >/dev/null 2>&1 || { echo ""; return 0; }

  local fsdir
  fsdir="$(get_assets_fsdir "$ns" "$deploy")"

  kubectl -n "$ns" get deploy "$deploy" -o json \
    | python3 -c "import json,sys
obj=json.load(sys.stdin)
fsdir='${fsdir}'
c=obj['spec']['template']['spec']['containers'][0]
mounts=c.get('volumeMounts',[]) or []
best=None
for m in mounts:
  mp=m.get('mountPath','')
  if mp and (fsdir==mp or fsdir.startswith(mp.rstrip('/')+'/')):
    if best is None or len(mp)>len(best.get('mountPath','')):
      best=m
if not best:
  print(''); raise SystemExit
vol_name=best['name']
mount_path=best['mountPath']
claim=''
for v in (obj['spec']['template']['spec'].get('volumes',[]) or []):
  if v.get('name')==vol_name:
    pvc=v.get('persistentVolumeClaim')
    if pvc:
      claim=pvc.get('claimName','')
    break
print(f\"{claim} {mount_path} {fsdir}\")"
}

migrate_assets_replace_in_place() {
  local src_ns="$1" dst_ns="$2"
  local src_deploy="penpot-backend"
  local dst_deploy="penpot-backend"

  log "Migrating assets (FS storage)..."
  log "Detecting assets PVC/mount (source/target)..."
  local src_info dst_info
  src_info="$(detect_assets_pvc_and_mount "$src_ns" "$src_deploy" || true)"
  dst_info="$(detect_assets_pvc_and_mount "$dst_ns" "$dst_deploy" || true)"
  [[ -n "$src_info" && -n "$dst_info" ]] || { echo "ERROR: cannot detect assets pvc/mount" >&2; return 1; }

  local SRC_PVC SRC_MOUNT SRC_ASSETSDIR
  local DST_PVC DST_MOUNT DST_ASSETSDIR
  read -r SRC_PVC SRC_MOUNT SRC_ASSETSDIR <<<"$src_info"
  read -r DST_PVC DST_MOUNT DST_ASSETSDIR <<<"$dst_info"

  log "Source assets: ns=$src_ns pvc=$SRC_PVC assetsdir=$SRC_ASSETSDIR"
  log "Target assets: ns=$dst_ns pvc=$DST_PVC assetsdir=$DST_ASSETSDIR"

  local tmpdir="/tmp/penpot-assets-${TS}"
  rm -rf "$tmpdir"
  mkdir -p "$tmpdir"

  # Helper pod in source
  kubectl -n "$src_ns" delete pod penpot-assets-src --ignore-not-found >/dev/null 2>&1 || true
  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: penpot-assets-src
  namespace: ${src_ns}
spec:
  restartPolicy: Never
  containers:
  - name: src
    image: alpine:3.20
    command: ["sh","-lc","sleep 3600"]
    volumeMounts:
    - name: assets
      mountPath: ${SRC_MOUNT}
  volumes:
  - name: assets
    persistentVolumeClaim:
      claimName: ${SRC_PVC}
YAML
  kubectl -n "$src_ns" wait --for=condition=Ready pod/penpot-assets-src --timeout=300s >/dev/null

  # Helper pod in target
  kubectl -n "$dst_ns" delete pod penpot-assets-dst --ignore-not-found >/dev/null 2>&1 || true
  cat <<YAML | kubectl apply -f - >/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: penpot-assets-dst
  namespace: ${dst_ns}
spec:
  restartPolicy: Never
  containers:
  - name: dst
    image: alpine:3.20
    command: ["sh","-lc","sleep 3600"]
    volumeMounts:
    - name: assets
      mountPath: ${DST_MOUNT}
  volumes:
  - name: assets
    persistentVolumeClaim:
      claimName: ${DST_PVC}
YAML
  kubectl -n "$dst_ns" wait --for=condition=Ready pod/penpot-assets-dst --timeout=300s >/dev/null

  log "Copying assets source -> local (${tmpdir})..."
  kubectl -n "$src_ns" cp "penpot-assets-src:${SRC_ASSETSDIR}" "${tmpdir}/assets"

  log "Wiping destination assets dir (${DST_ASSETSDIR})..."
  kubectl -n "$dst_ns" exec penpot-assets-dst -- sh -lc "
    set -e
    mkdir -p '${DST_ASSETSDIR}'
    rm -rf '${DST_ASSETSDIR%/}'/* '${DST_ASSETSDIR%/}'/.[!.]* '${DST_ASSETSDIR%/}'/..?* 2>/dev/null || true
  " >/dev/null

  log "Copying assets local -> destination (same directory)..."
  kubectl -n "$dst_ns" cp "${tmpdir}/assets/." "penpot-assets-dst:${DST_ASSETSDIR%/}/"

  log "Cleaning up asset helper pods..."
  kubectl -n "$src_ns" delete pod penpot-assets-src --ignore-not-found >/dev/null 2>&1 || true
  kubectl -n "$dst_ns" delete pod penpot-assets-dst --ignore-not-found >/dev/null 2>&1 || true
  rm -rf "$tmpdir"

  log "Assets replace done."
}

# =========================
# Main
# =========================

log "Stopping apps (source and target) to avoid writes..."
scale_apps "$NS_SRC" 0
scale_apps "$NS_DST" 0

# 1) Assets first (so DB restore doesn't reference missing blobs)
migrate_assets_replace_in_place "$NS_SRC" "$NS_DST"

# 2) Credentials
log "Reading credentials..."
SRC_PASS="$(get_src_pass)"
read DST_USER DST_PASS < <(get_dst_creds)

log "Source: host=${SRC_HOST} db=${SRC_DB} user=${SRC_USER}"
log "Target: host=${DST_HOST} db=${DST_DB} user=${DST_USER} (secret=${DST_SECRET})"

# 3) DB dump/restore
dump_db "$NS_SRC" "$SRC_HOST" "$SRC_PORT" "$SRC_USER" "$SRC_PASS" "$SRC_DB"

# sanity check target db reachable
if ! run_pg_cmd "$NS_DST" bash -lc "export PGPASSWORD='${DST_PASS}'; psql -h '${DST_HOST}' -p '${DST_PORT}' -U '${DST_USER}' -d '${DST_DB}' -c 'SELECT 1;' >/dev/null"; then
  echo "ERROR: Target database '${DST_DB}' does not exist or is not reachable." >&2
  exit 1
fi

reset_target_db_schema "$NS_DST" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB"
restore_db_via_cp "$NS_DST" "$DST_HOST" "$DST_PORT" "$DST_USER" "$DST_PASS" "$DST_DB"

# 4) Start target apps
log "Starting target apps..."
scale_apps "$NS_DST" 1

log "DONE ✅ Migration complete."
log "Backup file (local): ${DUMP_FILE}"
