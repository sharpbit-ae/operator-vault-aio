#!/bin/bash
# Deploy Vault AIO stack
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests"

echo "=== Deploying Vault AIO Stack ==="
echo ""

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "ERROR: kubectl not found"
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "1. Applying manifests with kustomize..."
kubectl apply -k "$MANIFESTS_DIR"

echo ""
echo "2. Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=vault -n vault-aio --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=prometheus -n vault-aio --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=grafana -n vault-aio --timeout=120s || true
kubectl wait --for=condition=ready pod -l app=loki -n vault-aio --timeout=120s || true

echo ""
echo "3. Pod status:"
kubectl get pods -n vault-aio

echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "1. Initialize Vault: ./scripts/init-vault.sh"
echo "2. Access Grafana: kubectl port-forward -n vault-aio svc/grafana 3000:3000"
echo "3. Access Vault: kubectl port-forward -n vault-aio svc/vault 8200:8200"
echo ""
echo "Default Grafana credentials: admin / vault-aio-admin"
