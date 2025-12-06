# Operator Vault AIO (All-In-One)

Standalone HashiCorp Vault deployment with integrated monitoring, logging, tracing, and time synchronization.

## Components

| Component | Purpose | Port |
|-----------|---------|------|
| **Vault** | Secrets management, PKI Root CA | 8200 |
| **Prometheus** | Metrics collection | 9090 |
| **Grafana** | Visualization & dashboards | 3000 |
| **Alertmanager** | Alert routing & notifications | 9093 |
| **Loki** | Log aggregation | 3100 |
| **Alloy** | Log/metric collection agent | 4317 |
| **Tempo** | Distributed tracing | 3200 |
| **Chrony** | NTP time synchronization | 123/udp |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     vault-aio namespace                          │
│                                                                  │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │    Vault     │────▶│  Prometheus  │────▶│   Grafana    │    │
│  │   (8200)     │     │   (9090)     │     │   (3000)     │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│         │                    │                    │             │
│         │                    ▼                    │             │
│         │             ┌──────────────┐            │             │
│         │             │ Alertmanager │            │             │
│         │             │   (9093)     │            │             │
│         │             └──────────────┘            │             │
│         │                                         │             │
│         ▼                                         ▼             │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐    │
│  │    Alloy     │────▶│     Loki     │────▶│    Tempo     │    │
│  │   (agent)    │     │   (3100)     │     │   (3200)     │    │
│  └──────────────┘     └──────────────┘     └──────────────┘    │
│         │                                                       │
│         ▼                                                       │
│  ┌──────────────┐                                              │
│  │   Chrony     │  (NTP sync for all pods)                     │
│  │  (123/udp)   │                                              │
│  └──────────────┘                                              │
│                                                                  │
│  ════════════════════════════════════════════════════════════  │
│                     NetworkPolicy: Deny All + Allow List        │
└─────────────────────────────────────────────────────────────────┘
```

## Network Policies

- **Default deny all** ingress/egress
- Explicit allows:
  - Vault ← Prometheus (metrics scraping)
  - Vault ← Ingress (API access)
  - Prometheus ← Grafana (queries)
  - Loki ← Grafana (log queries)
  - Tempo ← Grafana (trace queries)
  - Alloy → Loki/Tempo (log/trace shipping)
  - Alloy → VM host (node logs via hostPath)
  - Chrony ↔ external NTP servers
  - Alertmanager → external (notifications)

## Quick Start

```bash
# Deploy all components
kubectl apply -k manifests/

# Check status
kubectl get pods -n vault-aio

# Access Grafana
kubectl port-forward -n vault-aio svc/grafana 3000:3000

# Access Vault
kubectl port-forward -n vault-aio svc/vault 8200:8200
```

## Dashboards

Pre-configured Grafana dashboards:
- **Vault Overview** - Seal status, token usage, secret operations
- **Vault Audit Logs** - Authentication, policy violations, access patterns
- **VM System Metrics** - CPU, memory, disk, network for host VM
- **Container Logs** - All pod logs with filtering
- **Trace Explorer** - Request tracing through Vault

## Configuration

### Vault
- Auto-unseal: Configured via transit or cloud KMS
- Audit logging: Enabled, sent to Loki via Alloy
- Metrics: Prometheus endpoint enabled at /v1/sys/metrics

### Alerting Rules
- Vault sealed alert
- High token creation rate
- Authentication failures spike
- Certificate expiry warnings
- Disk space warnings

## Directory Structure

```
operator-vault-aio/
├── manifests/
│   ├── vault/           # Vault deployment, config, policies
│   ├── monitoring/      # Prometheus, Grafana, Alertmanager
│   ├── logging/         # Loki, Alloy
│   ├── tracing/         # Tempo
│   ├── ntp/             # Chrony
│   ├── network-policies/ # NetworkPolicy resources
│   └── dashboards/      # Grafana dashboard ConfigMaps
├── scripts/
│   ├── init-vault.sh    # Initialize and unseal Vault
│   └── backup.sh        # Backup Vault data
└── docs/
    └── RUNBOOK.md       # Operational procedures
```
