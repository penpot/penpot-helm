#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-penpot}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEPENDENCIES_DIR="${ROOT_DIR}/devel/dependencies"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-$(kubectl config current-context)}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

cleanup() {
  kubectl delete pod pg-check valkey-check \
    -n "${NAMESPACE}" \
    --context "${KUBECTL_CONTEXT}" \
    --ignore-not-found >/dev/null 2>&1 || true
}
trap cleanup EXIT

require_command kubectl

echo "Using namespace: ${NAMESPACE}"
echo "Using kubectl context: ${KUBECTL_CONTEXT}"
echo "Using dependencies directory: ${DEPENDENCIES_DIR}"

if ! kubectl get namespace "${NAMESPACE}" --context "${KUBECTL_CONTEXT}" >/dev/null 2>&1; then
  echo "Creating namespace ${NAMESPACE}..."
  kubectl create namespace "${NAMESPACE}" --context "${KUBECTL_CONTEXT}"
fi

echo "Applying PostgreSQL manifests..."
kubectl apply --context "${KUBECTL_CONTEXT}" -f "${DEPENDENCIES_DIR}/postgresql.pvc.yml"
kubectl apply --context "${KUBECTL_CONTEXT}" -f "${DEPENDENCIES_DIR}/postgresql.deployment.yml"
kubectl apply --context "${KUBECTL_CONTEXT}" -f "${DEPENDENCIES_DIR}/postgresql.service.yml"

echo "Applying Valkey manifests..."
kubectl apply --context "${KUBECTL_CONTEXT}" -f "${DEPENDENCIES_DIR}/valkey.deployment.yml"
kubectl apply --context "${KUBECTL_CONTEXT}" -f "${DEPENDENCIES_DIR}/valkey.service.yml"

echo "Waiting for PostgreSQL rollout..."
kubectl rollout status deployment/postgresql \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

echo "Waiting for Valkey rollout..."
kubectl rollout status deployment/valkey \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

echo "Waiting for deployments to be available..."
kubectl wait --for=condition=available deployment/postgresql \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

kubectl wait --for=condition=available deployment/valkey \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

echo "Checking services..."
kubectl get service postgresql -n "${NAMESPACE}" --context "${KUBECTL_CONTEXT}" >/dev/null
kubectl get service valkey -n "${NAMESPACE}" --context "${KUBECTL_CONTEXT}" >/dev/null

echo "Running PostgreSQL connectivity check..."
kubectl delete pod pg-check \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --ignore-not-found >/dev/null 2>&1 || true

kubectl apply --context "${KUBECTL_CONTEXT}" -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: pg-check
spec:
  restartPolicy: Never
  containers:
    - name: pg-check
      image: postgres:15
      env:
        - name: PGPASSWORD
          value: penpot
      command:
        - sh
        - -c
        - until pg_isready -h postgresql -p 5432 -U penpot -d penpot; do sleep 2; done
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/pg-check \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

echo "Running Valkey connectivity check..."
kubectl delete pod valkey-check \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --ignore-not-found >/dev/null 2>&1 || true

kubectl apply --context "${KUBECTL_CONTEXT}" -n "${NAMESPACE}" -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: valkey-check
spec:
  restartPolicy: Never
  containers:
    - name: valkey-check
      image: valkey/valkey:8.1
      command:
        - sh
        - -c
        - until valkey-cli -h valkey -p 6379 ping | grep -q PONG; do sleep 2; done
EOF

kubectl wait --for=jsonpath='{.status.phase}'=Succeeded pod/valkey-check \
  -n "${NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=180s

echo ""
echo "Dependencies are ready in namespace ${NAMESPACE}."
echo "- PostgreSQL: postgresql.${NAMESPACE}.svc.cluster.local:5432"
echo "- Valkey: valkey.${NAMESPACE}.svc.cluster.local:6379"
