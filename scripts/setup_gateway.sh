#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-penpot-cluster}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-kind-${CLUSTER_NAME}}"
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-1.5.1}"
ENVOY_GATEWAY_CHART_VERSION="${ENVOY_GATEWAY_CHART_VERSION:-1.8.1}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

require_command kubectl
require_command helm

echo "Installing Gateway API CRDs..."
kubectl apply --server-side --context "${KUBECTL_CONTEXT}" \
  -f "https://github.com/kubernetes-sigs/gateway-api/releases/download/v${GATEWAY_API_VERSION}/standard-install.yaml"

echo "Installing Envoy Gateway via Helm OCI chart..."
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --kube-context "${KUBECTL_CONTEXT}" \
  --namespace envoy-gateway-system \
  --create-namespace \
  --version "${ENVOY_GATEWAY_CHART_VERSION}" \
  --skip-crds

echo "Waiting for Envoy Gateway controller..."
kubectl rollout status deployment/envoy-gateway \
  -n envoy-gateway-system \
  --context "${KUBECTL_CONTEXT}" \
  --timeout=300s

echo "Creating local GatewayClass and Gateway..."
kubectl apply --context "${KUBECTL_CONTEXT}" \
  -f "${ROOT_DIR}/devel/penpot-gateway.yaml"
