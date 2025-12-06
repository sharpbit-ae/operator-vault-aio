#!/bin/bash
# Initialize and unseal Vault
# Run this script after the Vault pod is running

set -e

NAMESPACE="${NAMESPACE:-vault-aio}"
VAULT_POD=$(kubectl get pods -n $NAMESPACE -l app=vault -o jsonpath='{.items[0].metadata.name}')

echo "Vault pod: $VAULT_POD"

# Check if Vault is already initialized
INIT_STATUS=$(kubectl exec -n $NAMESPACE $VAULT_POD -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")

if [ "$INIT_STATUS" = "true" ]; then
    echo "Vault is already initialized"

    # Check if sealed
    SEAL_STATUS=$(kubectl exec -n $NAMESPACE $VAULT_POD -- vault status -format=json | jq -r '.sealed')
    if [ "$SEAL_STATUS" = "true" ]; then
        echo "Vault is sealed. Please unseal manually with your unseal keys."
        echo "Run: kubectl exec -n $NAMESPACE -it $VAULT_POD -- vault operator unseal"
    else
        echo "Vault is unsealed and ready"
    fi
    exit 0
fi

echo "Initializing Vault..."

# Initialize Vault with 5 key shares and 3 key threshold
INIT_OUTPUT=$(kubectl exec -n $NAMESPACE $VAULT_POD -- vault operator init -key-shares=5 -key-threshold=3 -format=json)

echo "$INIT_OUTPUT" > vault-init-keys.json
chmod 600 vault-init-keys.json

echo "=== IMPORTANT: SAVE THESE KEYS SECURELY ==="
echo "$INIT_OUTPUT" | jq -r '.unseal_keys_b64[]' | nl -v 1 | sed 's/^/Unseal Key /'
echo ""
echo "Root Token: $(echo "$INIT_OUTPUT" | jq -r '.root_token')"
echo ""
echo "Keys saved to vault-init-keys.json"
echo "============================================="

# Unseal Vault
echo "Unsealing Vault..."
for i in 1 2 3; do
    KEY=$(echo "$INIT_OUTPUT" | jq -r ".unseal_keys_b64[$((i-1))]")
    kubectl exec -n $NAMESPACE $VAULT_POD -- vault operator unseal "$KEY"
done

echo "Vault initialized and unsealed successfully!"

# Enable audit logging
ROOT_TOKEN=$(echo "$INIT_OUTPUT" | jq -r '.root_token')
kubectl exec -n $NAMESPACE $VAULT_POD -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault audit enable file file_path=stdout"

echo "Audit logging enabled"

# Enable Prometheus metrics
kubectl exec -n $NAMESPACE $VAULT_POD -- sh -c "VAULT_TOKEN=$ROOT_TOKEN vault write sys/config/telemetry prometheus_retention_time=30s disable_hostname=true"

echo "Prometheus metrics enabled"
