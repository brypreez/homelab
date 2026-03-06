# Monitoring Setup

Two-tier monitoring architecture: standalone Prometheus/Grafana for Proxmox node metrics and kube-prometheus-stack inside Kubernetes for cluster monitoring.

---

## Architecture Overview

```
Tier 1 — Proxmox Node Monitoring
LXC 101 (192.168.40.100)
├── Prometheus → scrapes Node Exporter on enode-a/b/c (port 9100)
└── Grafana → Node Exporter Full dashboard (ID: 1860)

Tier 2 — Kubernetes Cluster Monitoring
monitoring namespace (Helm: kube-prometheus-stack)
├── Prometheus Operator
├── Grafana (LoadBalancer: 192.168.20.200)
├── Alertmanager
├── kube-state-metrics
├── Node Exporter (DaemonSet on all 5 K8s nodes)
└── 28 pre-built dashboards
```

---

## Tier 1 — Proxmox Node Monitoring

### Node Exporter (Docker on each Proxmox node)

```bash
docker run -d \
  --name node-exporter \
  --restart always \
  --net="host" \
  --pid="host" \
  -v "/:/host:ro,rslave" \
  prom/node-exporter:latest \
  --path.rootfs=/host
```

Deployed on: enode-a (192.168.40.10), enode-b (192.168.40.11), enode-c (192.168.40.12)

### Prometheus Configuration

`/root/prometheus.yml` on LXC 101:

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "proxmox-nodes"
    static_configs:
      - targets: ["192.168.40.10:9100"]
        labels:
          instance: "enode-a"
      - targets: ["192.168.40.11:9100"]
        labels:
          instance: "enode-b"
      - targets: ["192.168.40.12:9100"]
        labels:
          instance: "enode-c"

  - job_name: "kube-state-metrics"
    static_configs:
      - targets: ["192.168.20.10:30080"]
```

### Prometheus Docker Run

```bash
docker run -d \
  --name prometheus \
  --restart always \
  -p 9090:9090 \
  -v /root/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus:latest
```

### Grafana Docker Run

```bash
docker run -d \
  --name grafana \
  --restart always \
  -p 3000:3000 \
  grafana/grafana:latest
```

**Dashboards:**
- Node Exporter Full (ID: 1860) — CPU, RAM, disk, network per Proxmox node

---

## Tier 2 — Kubernetes Cluster Monitoring

### Installation via Helm

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=<your-password>
```

### Expose Grafana via MetalLB

```bash
kubectl patch svc kube-prometheus-stack-grafana -n monitoring \
  -p '{"spec":{"type":"LoadBalancer"}}'
```

Grafana accessible at: `http://192.168.20.200`

### Included Dashboards

- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Node
- Kubernetes / Compute Resources / Pod
- Kubernetes / Networking / Cluster
- Kubernetes / API Server
- Kubernetes / Scheduler
- Kubernetes / etcd
- Node Exporter / Nodes
- Alertmanager / Overview
- And 19 more pre-built dashboards

---

## Upcoming

- [ ] Unified Grafana instance for both Proxmox and Kubernetes metrics
- [ ] Alertmanager rules for node down, high CPU, disk pressure
- [ ] Integration with Wazuh for security event correlation
- [ ] Grafana → Slack/email alerting

---

## Lessons Learned & Automation Goals

| Issue | Manual Fix | Automation Goal |
|-------|-----------|-----------------|
| Prometheus config requires manual restart on change | `docker restart prometheus` | Ansible playbook manages prometheus.yml with automatic reload |
| kube-state-metrics version mismatch | Manual Helm install + cleanup | Helm chart versions pinned in Git, managed via ArgoCD |
| Grafana dashboard variables require manual input | Type job/node per session | Provision dashboards as code via Grafana provisioning |
| No alerting configured | Manual dashboard monitoring | Alertmanager rules for node down, high CPU, disk pressure |

**Phase 2 Priority:** Ansible will manage Prometheus configuration across LXC 101. Grafana dashboards will be provisioned as code. Alertmanager rules will be defined in Git and deployed via ArgoCD.
