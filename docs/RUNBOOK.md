# Vault AIO Operational Runbook

## Quick Reference

### Access Services

```bash
# Grafana (dashboards)
kubectl port-forward -n vault-aio svc/grafana 3000:3000
# Open: http://localhost:3000 (admin / vault-aio-admin)

# Vault
kubectl port-forward -n vault-aio svc/vault 8200:8200
# Open: http://localhost:8200

# Prometheus
kubectl port-forward -n vault-aio svc/prometheus 9090:9090

# Alertmanager
kubectl port-forward -n vault-aio svc/alertmanager 9093:9093
```

### Check Status

```bash
# All pods
kubectl get pods -n vault-aio

# Vault seal status
kubectl exec -n vault-aio deploy/vault -- vault status

# Check logs
kubectl logs -n vault-aio deploy/vault
kubectl logs -n vault-aio deploy/grafana
kubectl logs -n vault-aio deploy/prometheus
```

---

## Common Operations

### Unseal Vault After Restart

Vault seals automatically when the pod restarts. You need 3 of 5 unseal keys.

```bash
VAULT_POD=$(kubectl get pods -n vault-aio -l app=vault -o jsonpath='{.items[0].metadata.name}')

# Unseal with each key (need 3)
kubectl exec -n vault-aio $VAULT_POD -- vault operator unseal <KEY_1>
kubectl exec -n vault-aio $VAULT_POD -- vault operator unseal <KEY_2>
kubectl exec -n vault-aio $VAULT_POD -- vault operator unseal <KEY_3>
```

### Create New Secret Engine

```bash
# Login first
kubectl exec -n vault-aio deploy/vault -- vault login <ROOT_TOKEN>

# Enable KV v2 secrets engine
kubectl exec -n vault-aio deploy/vault -- vault secrets enable -path=secret kv-v2

# Enable PKI secrets engine
kubectl exec -n vault-aio deploy/vault -- vault secrets enable pki
```

### Generate Root CA Certificate

```bash
kubectl exec -n vault-aio deploy/vault -- vault write pki/root/generate/internal \
    common_name="Vault AIO Root CA" \
    ttl=87600h
```

### View Logs in Grafana

1. Open Grafana at http://localhost:3000
2. Go to Explore
3. Select "Loki" datasource
4. Query: `{namespace="vault-aio"}`

### View Traces

1. Open Grafana at http://localhost:3000
2. Go to Explore
3. Select "Tempo" datasource
4. Search by trace ID or service name

---

## Troubleshooting

### Vault Won't Start

**Symptoms:** Pod stuck in CrashLoopBackOff

**Check:**
```bash
kubectl logs -n vault-aio deploy/vault
kubectl describe pod -n vault-aio -l app=vault
```

**Common causes:**
- PVC not bound - check storage class
- Config error - validate vault.hcl syntax
- Permission issues - check securityContext

### Prometheus Not Scraping

**Symptoms:** No metrics in Grafana

**Check:**
```bash
# Check Prometheus targets
kubectl port-forward -n vault-aio svc/prometheus 9090:9090
# Open http://localhost:9090/targets

# Check Prometheus logs
kubectl logs -n vault-aio deploy/prometheus
```

**Common causes:**
- NetworkPolicy blocking traffic
- Service selector mismatch
- Pod annotations missing

### Loki Not Receiving Logs

**Symptoms:** Empty logs in Grafana

**Check:**
```bash
# Check Alloy logs
kubectl logs -n vault-aio ds/alloy

# Check Loki ready
kubectl exec -n vault-aio deploy/loki -- wget -qO- http://localhost:3100/ready
```

**Common causes:**
- Alloy not running (DaemonSet issues)
- Loki not ready
- Volume mount issues for log collection

### High Memory Usage

**Symptoms:** OOMKilled pods

**Fix:**
```bash
# Increase limits in deployment
kubectl edit deployment -n vault-aio <deployment-name>
# Modify resources.limits.memory
```

### NTP Sync Issues

**Symptoms:** Time drift between pods

**Check:**
```bash
kubectl exec -n vault-aio ds/chrony -c chrony -- chronyc tracking
kubectl exec -n vault-aio ds/chrony -c chrony -- chronyc sources
```

---

## Alerts Reference

| Alert | Severity | Description | Action |
|-------|----------|-------------|--------|
| VaultSealed | Critical | Vault is sealed | Unseal with keys |
| VaultDown | Critical | Vault not responding | Check pod status |
| VaultHighTokenCreation | Warning | >100 tokens/sec | Check for token leak |
| VaultAuthFailures | Warning | Many auth failures | Check for brute force |
| HighMemoryUsage | Warning | Memory >90% | Scale or increase limits |
| HighDiskUsage | Warning | Disk >85% | Clean up or expand PVC |
| HighCPUUsage | Warning | CPU >80% for 10min | Check for runaway process |

---

## Backup & Recovery

### Backup Vault Data

```bash
# Create snapshot
kubectl exec -n vault-aio deploy/vault -- vault operator raft snapshot save /tmp/vault-backup.snap

# Copy to local
kubectl cp vault-aio/$(kubectl get pods -n vault-aio -l app=vault -o jsonpath='{.items[0].metadata.name}'):/tmp/vault-backup.snap ./vault-backup.snap
```

### Restore Vault Data

```bash
# Copy snapshot to pod
kubectl cp ./vault-backup.snap vault-aio/<vault-pod>:/tmp/vault-backup.snap

# Restore (requires root token)
kubectl exec -n vault-aio deploy/vault -- vault operator raft snapshot restore /tmp/vault-backup.snap
```

### Backup Grafana Dashboards

Dashboards are stored as ConfigMaps and are automatically backed up with the Git repo.

---

## Maintenance

### Rolling Update

```bash
# Update image
kubectl set image deployment/vault vault=hashicorp/vault:1.16 -n vault-aio

# Watch rollout
kubectl rollout status deployment/vault -n vault-aio
```

### Scale Prometheus Storage

```bash
# Edit PVC (requires storage class support)
kubectl patch pvc prometheus-data -n vault-aio -p '{"spec":{"resources":{"requests":{"storage":"50Gi"}}}}'
```

### Rotate Grafana Admin Password

```bash
kubectl create secret generic grafana-admin -n vault-aio \
    --from-literal=password='new-secure-password' \
    --dry-run=client -o yaml | kubectl apply -f -

# Restart Grafana
kubectl rollout restart deployment/grafana -n vault-aio
```
