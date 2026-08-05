#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-penpot-cluster}"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-kind-${CLUSTER_NAME}}"
GATEWAY_NAMESPACE="${GATEWAY_NAMESPACE:-penpot}"
GATEWAY_NAME="${GATEWAY_NAME:-penpot}"
ENVOY_NAMESPACE="${ENVOY_NAMESPACE:-envoy-gateway-system}"
LOCAL_PORT="${LOCAL_PORT:-8888}"
REMOTE_PORT="${REMOTE_PORT:-80}"

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

require_command kubectl

echo "Finding Envoy service for Gateway ${GATEWAY_NAMESPACE}/${GATEWAY_NAME}..."
ENVOY_SERVICE="$(
  kubectl get svc \
    -n "${ENVOY_NAMESPACE}" \
    --context "${KUBECTL_CONTEXT}" \
    --selector="gateway.envoyproxy.io/owning-gateway-namespace=${GATEWAY_NAMESPACE},gateway.envoyproxy.io/owning-gateway-name=${GATEWAY_NAME}" \
    -o jsonpath='{.items[0].metadata.name}'
)"

if [[ -z "${ENVOY_SERVICE}" ]]; then
  echo "Error: Envoy service not found for Gateway ${GATEWAY_NAMESPACE}/${GATEWAY_NAME}." >&2
  echo "Check Gateway status with: kubectl get gateway,httproute -n ${GATEWAY_NAMESPACE}" >&2
  exit 1
fi

echo "Forwarding http://penpot.example.com:${LOCAL_PORT}/ to service/${ENVOY_SERVICE}:${REMOTE_PORT}"
kubectl port-forward \
  -n "${ENVOY_NAMESPACE}" \
  --context "${KUBECTL_CONTEXT}" \
  "service/${ENVOY_SERVICE}" \
  "${LOCAL_PORT}:${REMOTE_PORT}"
