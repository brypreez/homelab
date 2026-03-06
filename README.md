# 🏠 Bryan's Homelab

A self-built, enterprise-grade homelab running a 3-node Proxmox cluster, VLAN-segmented network, and a 5-node Kubernetes HA cluster — built from scratch on consumer hardware.

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
| 10 | Management | 192.168.10.0/24 | Proxmox nodes, Pi-hole, workstation |
| 20 | Lab | 192.168.20.0/24 | Kubernetes VMs |
| 30 | IoT | 192.168.30.0/24 | IoT devices (isolated) |
| 40 | Servers | 192.168.40.0/24 | Proxmox node management |

**Firewall Rules:**
- VLAN 30 (IoT) → VLAN 20 (Lab): BLOCKED
- All VLANs → Pi-hole (192.168.10.2): DNS allowed
- MetalLB pool reserved: 192.168.20.200–220

---

## 🔧 Proxmox Cluster

3-node Proxmox VE cluster with VLAN-aware bridges on all nodes.

| Node | IP | Role |
|------|----|------|
| enode-a | 192.168.40.10 | Primary |
| enode-b | 192.168.40.11 | Secondary |
| enode-c | 192.168.40.12 | Secondary |

**Running Services:**
- LXC 100 — Pi-hole DNS (192.168.10.2, VLAN 10)
- LXC 101 — Grafana Stack (192.168.40.100, VLAN 40)

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
- OS: Ubuntu 22.04 LTS (cloud-init)

**In Progress:**
- MetalLB load balancer
- ArgoCD GitOps pipeline
- Wazuh SIEM
- Terraform + Ansible IaC

---

## 📁 Repo Structure

```
homelab/
├── README.md                  # This file
├── docs/
│   ├── network-setup.md       # VLAN configuration guide
│   ├── proxmox-setup.md       # Proxmox cluster setup
│   ├── kubernetes-setup.md    # K8s cluster installation
│   └── troubleshooting.md     # Issues encountered and fixes
├── kubernetes/
│   ├── manifests/             # K8s YAML manifests
│   └── helm/                  # Helm chart values
├── terraform/                 # Infrastructure as Code
└── ansible/                   # Configuration management
```

---

## 🎯 Goals

- [x] VLAN network segmentation
- [x] 3-node Proxmox HA cluster
- [x] Pi-hole DNS
- [x] 5-node Kubernetes HA cluster
- [ ] MetalLB load balancer
- [ ] ArgoCD GitOps
- [ ] Wazuh SIEM
- [ ] Terraform provisioning
- [ ] Ansible configuration management
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

*Self-taught. Everything here actually runs.*
