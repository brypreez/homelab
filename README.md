# 🏠 Bryan's Homelab

A self-built, production-grade homelab running a 3-node Proxmox cluster, VLAN-segmented network, 5-node Kubernetes HA cluster, and a full Wazuh SIEM/XDR security stack — built from scratch on consumer hardware and operated to a 99.9% uptime standard with strict change management protocols.

> This lab is treated as a **Production Environment**. All changes follow a documented change management process, infrastructure is defined as code, and every major decision is version-controlled in this repository. Uptime target: 99.9%. All service modifications require a documented change window.

---

## 🖥️ Hardware

| Node | Model | CPU | RAM | Storage |
|------|-------|-----|-----|---------|
| enode-a | HP EliteDesk G6 Mini | Intel i5 | 32GB | 1TB NVMe |
| enode-b | HP EliteDesk G5 Mini | Intel i5 | 16GB | 1TB NVMe |
| enode-c | HP EliteDesk G5 Mini | Intel i5 | 16GB | 1TB NVMe |

**Networking:**
- Router: TP-Link ER605
- Switch: Netgear GS308E (8-port managed)

---

## 🌐 Network Architecture

| VLAN | Name | Subnet | Purpose |
|------|------|--------|---------|
| 10 | Management | 192.168.10.0/24 | Workstation, Pi-hole DNS |
| 20 | Lab | 192.168.20.0/24 | Kubernetes VMs |
| 30 | IoT | 192.168.30.0/24 | IoT devices (isolated) |
| 40 | Servers | 192.168.40.0/24 | Proxmox nodes, Wazuh, Grafana |

**Firewall Rules:**
- VLAN 30 (IoT) → VLAN 20 (Lab): BLOCKED
- All VLANs → Pi-hole (192.168.10.2): DNS allowed
- MetalLB pool: 192.168.20.200–220

---

## 🔧 Proxmox Cluster

3-node Proxmox VE cluster with VLAN-aware bridges on all nodes. All services configured with `Start at Boot` enabled — operated to 99.9% uptime with documented change management.

| Node | IP | Role |
|------|----|------|
| enode-a | 192.168.40.10 | Primary |
| enode-b | 192.168.40.11 | Secondary |
| enode-c | 192.168.40.12 | Secondary |

**Running Services:**

| LXC | Service | IP | VLAN | Uptime Target |
|-----|---------|-----|------|---------------|
| 100 | Pi-hole DNS | 192.168.10.2 | 10 | 99.9% |
| 101 | Grafana + Prometheus | 192.168.40.100 | 40 | 99.9% |
| 102 | Wazuh SIEM/XDR | 192.168.40.20 | 40 | 99.9% |

---

## ☸️ Kubernetes HA Cluster

5-node Kubernetes cluster with 3 control planes and 2 workers — built with kubeadm.

| VM | Node | Role | IP | RAM | Disk |
|----|------|------|----|-----|------|
| k8s-master-1 | enode-a | Control Plane | 192.168.20.10 | 4GB | 22GB |
| k8s-master-2 | enode-b | Control Plane | 192.168.20.11 | 4GB | 38GB |
| k8s-master-3 | enode-c | Control Plane | 192.168.20.12 | 4GB | 38GB |
| k8s-worker-1 | enode-a | Worker | 192.168.20.20 | 8GB | 50GB |
| k8s-worker-2 | enode-a | Worker | 192.168.20.21 | 8GB | 50GB |

**Stack:**
- Kubernetes v1.32.13
- Container Runtime: containerd
- CNI: Flannel (pod CIDR: 10.244.0.0/16)
- Load Balancer: MetalLB (pool: 192.168.20.200–220)
- GitOps: ArgoCD (192.168.20.201)
- Monitoring: kube-prometheus-stack via Helm (Grafana: 192.168.20.200)

---

## 🔐 Security Stack — Wazuh SIEM/XDR

Wazuh 4.14.3 deployed on a dedicated LXC (192.168.40.20) monitoring all infrastructure endpoints.

**Monitored Endpoints (8 agents):**
- enode-a, enode-b, enode-c (Proxmox nodes)
- k8s-master-1, k8s-master-2, k8s-master-3 (Control Planes)
- k8s-worker-1, k8s-worker-2 (Workers)

**Active Capabilities:**
- CIS Ubuntu 22.04 LTS benchmark compliance scanning
- File Integrity Monitoring (FIM) — including `/etc/kubernetes/manifests` on all control planes
- Custom rule 110005 — level 10 alert on K8s manifest tampering
- Real-time Slack alerting via Incoming Webhook → `#security-alerts`
- Custom dashboards: Security Noise Map, Top Attacker IPs

**Secret Management:**
Sensitive keys (Slack webhook URLs, API tokens) are stored in Ansible Vault and injected at deploy time. No secrets are committed to this repository — placeholders are used in all config examples.
```mermaid
graph LR
    A[K8s Master Node] -->|FIM Event| B[Wazuh Agent]
    B -->|Rule 110005 Match| C[Wazuh Manager]
    C -->|Webhook| D[Slack API]
    D -->|Real-time Alert| E[#security-alerts]
```

---

## 🔥 Featured Troubleshooting

### IPv4/IPv6 Protocol Stack Preference Conflict — Wazuh Dashboard ↔ Indexer

**Symptom:** `ECONNREFUSED ::1:9200` — dashboard couldn't connect to indexer despite both services running and passing health checks.

**Root Cause:** Modern Linux distributions follow RFC 6724, which gives IPv6 addresses higher precedence in the default address selection algorithm. When the dashboard resolved `localhost`, the OS returned `::1` (IPv6 loopback) rather than `127.0.0.1` (IPv4 loopback). The Wazuh Indexer (OpenSearch) was explicitly bound to `127.0.0.1` via `network.host`, creating a protocol stack mismatch that manifested as a silent connection refusal — not a firewall block, not a service failure.

**Fix:** Updated `opensearch.hosts` in `/etc/wazuh-dashboard/opensearch_dashboards.yml` to bypass OS address resolution entirely by using an explicit IPv4 address:

```yaml
opensearch.hosts: ["https://127.0.0.1:9200"]
opensearch.ssl.verificationMode: none
```

**Engineering Lesson:** Never rely on `localhost` hostname resolution in service-to-service communication on dual-stack Linux systems. Always bind and connect to explicit IP addresses. This class of bug is particularly insidious because all services report healthy status — the failure lives entirely in the network layer handoff between components.

---

## 📁 Repo Structure

```
homelab/
├── README.md
├── docs/
│   ├── network-setup.md
│   ├── kubernetes-setup.md
│   ├── monitoring-setup.md
│   ├── wazuh-setup.md
│   └── troubleshooting.md
├── kubernetes/
│   ├── apps/
│   │   └── nginx-test.yaml
│   └── infrastructure/
├── ansible/
│   ├── playbooks/
│   └── inventory/
└── terraform/
    └── proxmox/
```

---

## 🎯 Roadmap

### Phase 1 — Foundation ✅
- [x] VLAN network segmentation
- [x] 3-node Proxmox HA cluster
- [x] Pi-hole DNS
- [x] 5-node Kubernetes HA cluster
- [x] MetalLB load balancer
- [x] ArgoCD GitOps pipeline
- [x] Prometheus + Grafana monitoring (two-tier)
- [x] Wazuh SIEM/XDR (8 endpoints)
- [x] Custom FIM rules for K8s control plane manifests
- [x] Real-time Slack alerting pipeline (Rule 110005 → #security-alerts)

### Phase 2 — Infrastructure as Code 🔄

**Ansible (Configuration Management):**
- [ ] Inventory file defining all Proxmox nodes and K8s VMs
- [ ] Playbook: Wazuh agent deployment and `ossec.conf` management across all endpoints
- [ ] Playbook: Proxmox node hardening and configuration drift remediation
- [ ] Playbook: `opensearch_dashboards.yml` configuration management (self-healing)

**Terraform (Provisioning):**
- [ ] Telmate/Proxmox provider setup and authentication
- [ ] Module: K8s worker node provisioning from cloud-init template
- [ ] Module: Security VM provisioning (future Wazuh agents)
- [ ] State backend configuration

**Kubernetes Security (CKA Alignment):**
- [ ] Kubernetes Audit Logging → Wazuh pipeline (`kube-apiserver` manifest configuration)
- [ ] Ingress controller (nginx) + cert-manager for TLS
- [ ] RBAC hardening across namespaces

### Phase 3 — Advanced
- [ ] Vaultwarden self-hosted password manager
- [ ] Rook-Ceph persistent storage
- [ ] GitHub Actions CI/CD pipeline
- [ ] CKA certification

---

## 📜 Certifications

| Cert | Status |
|------|--------|
| CompTIA A+ | ✅ Earned |
| CompTIA Network+ | 🔄 In Progress |
| CompTIA Security+ | 🔄 In Progress |
| Cisco CCNA | 🔄 In Progress |
| CKA | 🔄 In Progress |

---

## 💼 Key Resume Bullets

- Architected and deployed a hybrid Wazuh SIEM/XDR solution securing 8 multi-platform endpoints and 5 Kubernetes nodes; resolved complex IPv4/IPv6 networking conflicts and SSL/TLS handshake issues to ensure 100% data ingestion
- Engineered a real-time security orchestration pipeline integrating Wazuh SIEM with Slack API — custom XML detection rules (Rule 110005) trigger level-10 alerts for Kubernetes control plane manifest tampering, delivered to SOC channel within seconds
- Developed granular FIM detection for Kubernetes control plane by extending ossec.conf to monitor `/etc/kubernetes/manifests` with realtime alerting — eliminates blind spot for supply chain attacks and unauthorized control plane modifications
- Implemented GitOps pipeline using ArgoCD with automated sync, self-healing, and pruning — integrated with GitHub via SSH deploy keys for secure repository access
- Built a 5-node Kubernetes HA cluster using kubeadm with 3 control planes, Flannel CNI, and MetalLB load balancer on self-hosted Proxmox infrastructure
- Designed and implemented VLAN-segmented network across 4 VLANs with inter-VLAN routing, firewall policies, and Pi-hole DNS serving all segments
- Authored idempotent Ansible playbooks for Wazuh configuration management across 8-node fleet; validated baseline configuration compliance across mixed Ubuntu/Debian environment
- Validated Terraform infrastructure-as-code plan for Proxmox VM provisioning using bpg/proxmox provider with cloud-init integration and static VLAN networking

---

*Self-taught. Everything here actually runs. Operated to production standards.*
