# Vault AIO (All-In-One)

Standalone HashiCorp Vault deployment with integrated observability stack, running on Kubernetes (k3d).

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Vault AIO VM (10.0.0.20)                     │
│  ┌─────────────────────────────────────────────────────────────────┐ │
│  │                    k3d Kubernetes Cluster                        │ │
│  │  ┌──────────────────────────────────────────────────────────┐   │ │
│  │  │                    vault-aio namespace                    │   │ │
│  │  │  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌───────────┐   │   │ │
│  │  │  │  Vault  │  │ Grafana  │  │ Prom    │  │ Alert Mgr │   │   │ │
│  │  │  │  :8200  │  │  :3000   │  │ :9090   │  │   :9093   │   │   │ │
│  │  │  └─────────┘  └──────────┘  └─────────┘  └───────────┘   │   │ │
│  │  │  ┌─────────┐  ┌──────────┐  ┌─────────┐  ┌───────────┐   │   │ │
│  │  │  │  Loki   │  │  Tempo   │  │  Alloy  │  │  Chrony   │   │   │ │
│  │  │  │  :3100  │  │  :3200   │  │ (DS)    │  │   (DS)    │   │   │ │
│  │  │  └─────────┘  └──────────┘  └─────────┘  └───────────┘   │   │ │
│  │  └──────────────────────────────────────────────────────────┘   │ │
│  │  ┌──────────────────┐  ┌──────────────────────────────────────┐ │ │
│  │  │ kube-system      │  │ argocd namespace                     │ │ │
│  │  │ ┌──────────────┐ │  │ ┌──────────────────────────────────┐ │ │ │
│  │  │ │   Traefik    │ │  │ │          ArgoCD                  │ │ │ │
│  │  │ │  :80/:443    │ │  │ │    GitOps Continuous Delivery    │ │ │ │
│  │  │ └──────────────┘ │  │ └──────────────────────────────────┘ │ │ │
│  │  └──────────────────┘  └──────────────────────────────────────┘ │ │
│  └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

## Components

| Component | Version | Purpose | Port |
|-----------|---------|---------|------|
| **HashiCorp Vault** | 1.17 | Secrets management (dev mode) | 8200 |
| **Grafana** | 11.0 | Visualization & dashboards | 3000 |
| **Prometheus** | 2.52 | Metrics collection | 9090 |
| **Alertmanager** | 0.27 | Alert routing & notifications | 9093 |
| **Loki** | 3.0 | Log aggregation | 3100 |
| **Tempo** | 2.4 | Distributed tracing | 3200 |
| **Alloy** | 1.0 | Telemetry collector (DaemonSet) | 4317 |
| **Chrony** | - | NTP time synchronization (DaemonSet) | 123/UDP |
| **Traefik** | 2.11 | Ingress controller with TLS | 80/443 |
| **cert-manager** | 1.14 | Certificate management | - |
| **ArgoCD** | 3.2 | GitOps continuous delivery | 80 |

## Quick Start

### Prerequisites

- KVM/QEMU/libvirt installed
- SSH key at `~/.ssh/id_rsa`
- Network bridge configured (10.0.0.0/24)

### Deploy the VM

```bash
cd ansible
ansible-playbook deploy.yml
```

### Access Services

Add to `/etc/hosts`:
```
10.0.0.20 vault-aio.local vault.vault-aio.local grafana.vault-aio.local prometheus.vault-aio.local alertmanager.vault-aio.local loki.vault-aio.local tempo.vault-aio.local argocd.vault-aio.local
```

| Service | URL | Credentials |
|---------|-----|-------------|
| Homepage | https://vault-aio.local | - |
| Vault | https://vault.vault-aio.local | Token: `root` |
| Grafana | https://grafana.vault-aio.local | admin / (see below) |
| Prometheus | https://prometheus.vault-aio.local | - |
| Alertmanager | https://alertmanager.vault-aio.local | - |
| ArgoCD | https://argocd.vault-aio.local | admin / (see below) |

Get application passwords (stored in Vault):
```bash
# Grafana password
ssh aeonuser@10.0.0.20 "sudo kubectl get secret vault-app-passwords -n vault-aio -o jsonpath='{.data.grafana-password}' | base64 -d"

# ArgoCD password
ssh aeonuser@10.0.0.20 "sudo kubectl get secret vault-app-passwords -n vault-aio -o jsonpath='{.data.argocd-password}' | base64 -d"
```

## Features

- **Vault PKI**: Root and Intermediate CA managed by Vault with ACME support
- **TLS Everywhere**: Certificates issued by Vault PKI via cert-manager
- **HTTP to HTTPS Redirect**: All HTTP traffic redirects to HTTPS (301)
- **GitOps**: ArgoCD syncs with this repository automatically
- **Network Policies**: Strict pod-to-pod communication rules
- **CIS Hardening**: VM hardened according to CIS benchmarks
- **Observability**: Full metrics, logs, and traces pipeline

## Network Policies

- **Default deny all** ingress/egress
- Explicit allows:
  - Vault ← Prometheus (metrics scraping)
  - Vault ← Ingress (API access)
  - Prometheus ← Grafana (queries)
  - Loki ← Grafana (log queries)
  - Tempo ← Grafana (trace queries)
  - Alloy → Loki/Tempo (log/trace shipping)
  - Chrony ↔ external NTP servers
  - Alertmanager → external (notifications)
  - All pods → DNS (port 53)

## Directory Structure

```
operator-vault-aio/
├── ansible/                 # Ansible deployment automation
│   ├── deploy.yml          # Main playbook
│   └── inventory.yml       # Inventory configuration
├── argocd/                  # ArgoCD application manifests
│   └── application.yaml    # Vault AIO app definition
└── manifests/              # Kubernetes manifests (kustomize)
    ├── kustomization.yaml  # Kustomize configuration
    ├── namespace.yaml      # Namespace definition
    ├── vault/              # Vault configuration & deployment
    ├── monitoring/         # Prometheus, Grafana, Alertmanager
    ├── logging/            # Loki, Alloy
    ├── tracing/            # Tempo
    ├── ntp/                # Chrony
    ├── ingress/            # Traefik, Homepage, Ingress rules
    ├── cert-manager/       # ClusterIssuer configuration
    ├── network-policies/   # Network security policies
    └── dashboards/         # Grafana dashboard ConfigMaps
```

## Dashboards

Pre-configured Grafana dashboards:
- **Vault Overview** - Seal status, token usage, secret operations
- **Vault Audit Logs** - Authentication, policy violations, access patterns
- **VM System Metrics** - CPU, memory, disk, network for host VM
- **Container Logs** - All pod logs with filtering
- **Trace Explorer** - Request tracing through Vault

## Customization

### Change VM Resources

Edit `ansible/inventory.yml`:
```yaml
vault_aio:
  vm_memory: 8192   # MB
  vm_vcpus: 4
  vm_disk_size: 100G
```

### Add Custom Dashboards

Place dashboard JSON in `manifests/dashboards/` and update `manifests/dashboards/configmap.yaml`.

### Modify Network Policies

Edit files in `manifests/network-policies/` to adjust pod communication rules.

## Troubleshooting

### Check Pod Status
```bash
ssh aeonuser@10.0.0.20 "sudo kubectl get pods -n vault-aio"
```

### View Logs
```bash
ssh aeonuser@10.0.0.20 "sudo kubectl logs -n vault-aio deployment/<name>"
```

### Restart a Service
```bash
ssh aeonuser@10.0.0.20 "sudo kubectl rollout restart -n vault-aio deployment/<name>"
```

### Force ArgoCD Sync
```bash
ssh aeonuser@10.0.0.20 "sudo kubectl patch application vault-aio -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'"
```

### Trust the Vault CA Certificate
```bash
# Export Root CA certificate from Vault
ssh aeonuser@10.0.0.20 "sudo kubectl get secret vault-root-ca -n vault-aio -o jsonpath='{.data.ca\\.crt}' | base64 -d" > vault-aio-root-ca.crt

# Add to system trust (Linux)
sudo cp vault-aio-root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

## Security Notes

- Vault is running in **dev mode** (not for production)
- TLS certificates are signed by Vault's PKI (add Root CA to trust store for browsers)
- Application passwords (Grafana, ArgoCD) are auto-generated and stored in Vault
- Vault root token and keys are stored as Kubernetes secrets
- SSH password authentication is disabled (key-only)
- nftables firewall configured on VM

## Vault PKI Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Vault PKI Secrets Engine                  │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │                    Root CA (pki/)                        │ │
│  │         "Vault AIO Root CA" - 10 year TTL               │ │
│  └───────────────────────┬─────────────────────────────────┘ │
│                          │ signs                             │
│  ┌───────────────────────▼─────────────────────────────────┐ │
│  │              Intermediate CA (pki_int/)                  │ │
│  │     "Vault AIO Intermediate CA" - 5 year TTL            │ │
│  │                                                          │ │
│  │  Roles:                                                  │ │
│  │  - vault-aio-local: *.vault-aio.local certs             │ │
│  │  - cert-manager: certs for cert-manager                  │ │
│  │                                                          │ │
│  │  ACME Endpoint: /v1/pki_int/acme/directory              │ │
│  └──────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
           │
           │ issues certificates via
           ▼
┌─────────────────────────────────────────────────────────────┐
│              cert-manager (ClusterIssuer)                    │
│                   vault-pki-issuer                           │
│                          │                                   │
│      ┌───────────────────┼───────────────────┐              │
│      ▼                   ▼                   ▼              │
│  vault-aio-tls      argocd-tls         (other certs)       │
└─────────────────────────────────────────────────────────────┘
```

## License

MIT
