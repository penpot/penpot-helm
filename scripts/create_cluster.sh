#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-penpot-cluster}"
NAMESPACE="${NAMESPACE:-penpot}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECTL_CONTEXT="kind-${CLUSTER_NAME}"
INGRESS_MANIFEST_URL="${INGRESS_MANIFEST_URL:-https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml}"
EXPOSURE_MODE="${EXPOSURE_MODE:-ingress}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

require_command kind
require_command kubectl

echo "Creating kind cluster: ${CLUSTER_NAME}"
kind create cluster --name "${CLUSTER_NAME}" --config "${ROOT_DIR}/devel/kind.config.yml"

echo "Creating namespace: ${NAMESPACE}"
kubectl apply -f "${ROOT_DIR}/devel/penpot-namespace.yml" --context "${KUBECTL_CONTEXT}"

echo "Configuring kubectl context alias: ${NAMESPACE}"
kubectl config set-context "${NAMESPACE}" \
  --namespace="${NAMESPACE}" \
  --cluster="${KUBECTL_CONTEXT}" \
  --user="${KUBECTL_CONTEXT}"

kubectl config use-context "${NAMESPACE}"

if [[ "${EXPOSURE_MODE}" == "ingress" ]]; then
  echo "Installing ingress-nginx for kind..."
  kubectl apply --context "${KUBECTL_CONTEXT}" -f "${INGRESS_MANIFEST_URL}"

  echo "Waiting for ingress-nginx controller..."
  kubectl rollout status deployment/ingress-nginx-controller \
    -n ingress-nginx \
    --context "${KUBECTL_CONTEXT}" \
    --timeout=180s
elif [[ "${EXPOSURE_MODE}" == "gateway" ]]; then
  echo "Installing Gateway API stack for kind..."
  KUBECTL_CONTEXT="${KUBECTL_CONTEXT}" "${ROOT_DIR}/scripts/setup_gateway.sh"
else
  echo "Error: unsupported EXPOSURE_MODE=${EXPOSURE_MODE}. Use 'ingress' or 'gateway'." >&2
  exit 1
fi

echo "Setting up local PostgreSQL and Valkey dependencies..."
NAMESPACE="${NAMESPACE}" KUBECTL_CONTEXT="${KUBECTL_CONTEXT}" "${ROOT_DIR}/scripts/setup_dependencies.sh"

echo ""
echo "Cluster is ready."
echo "- kind cluster: ${CLUSTER_NAME}"
echo "- kubectl context alias: ${NAMESPACE}"
echo "- namespace: ${NAMESPACE}"
echo "- exposure mode: ${EXPOSURE_MODE}"
