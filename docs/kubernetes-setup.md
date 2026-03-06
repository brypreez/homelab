# Kubernetes HA Cluster Setup

5-node Kubernetes HA cluster built with kubeadm on Ubuntu 22.04 VMs running on Proxmox.

---

## Architecture

```
                    ┌─────────────────────────────┐
                    │     VLAN 20 (Lab Network)    │
                    │       192.168.20.0/24        │
                    └─────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
   k8s-master-1         k8s-master-2         k8s-master-3
   192.168.20.10        192.168.20.11        192.168.20.12
   (enode-a)            (enode-b)            (enode-c)
   etcd leader          etcd member          etcd member
          │
          ├──────────────────────┐
          ▼                      ▼
   k8s-worker-1           k8s-worker-2
   192.168.20.20           192.168.20.21
   (enode-a)               (enode-a)
```

---

## VM Specifications

| VM | Role | IP | RAM | Disk | Host Node |
|----|------|----|-----|------|-----------|
| k8s-master-1 | Control Plane | 192.168.20.10 | 4GB | 22GB | enode-a |
| k8s-master-2 | Control Plane | 192.168.20.11 | 4GB | 38GB | enode-b |
| k8s-master-3 | Control Plane | 192.168.20.12 | 4GB | 38GB | enode-c |
| k8s-worker-1 | Worker | 192.168.20.20 | 8GB | 50GB | enode-a |
| k8s-worker-2 | Worker | 192.168.20.21 | 8GB | 50GB | enode-a |

**OS:** Ubuntu 22.04 LTS (cloud-init template cloned from Proxmox VM 9000)

---

## Prerequisites (all nodes)

### 1. Disable swap
```bash
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### 2. Load kernel modules
```bash
cat >> /etc/modules-load.d/k8s.conf << 'EOF'
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter
```

### 3. Set sysctl params
```bash
cat >> /etc/sysctl.d/k8s.conf << 'EOF'
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system
```

### 4. Install containerd
```bash
apt install -y containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd
```

### 5. Install kubeadm, kubelet, kubectl
```bash
apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet
```

---

## Cluster Initialization

### Initialize first control plane (k8s-master-1 only)
```bash
kubeadm init \
  --control-plane-endpoint "192.168.20.10:6443" \
  --upload-certs \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=192.168.20.10
```

### Configure kubectl
```bash
mkdir -p $HOME/.kube
cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```

### Install Flannel CNI
```bash
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
```

### Join additional control planes (k8s-master-2 and k8s-master-3)
```bash
kubeadm join 192.168.20.10:6443 --token <token> \
        --discovery-token-ca-cert-hash sha256:<hash> \
        --control-plane --certificate-key <cert-key>
```

### Join worker nodes (k8s-worker-1 and k8s-worker-2)
```bash
kubeadm join 192.168.20.10:6443 --token <token> \
        --discovery-token-ca-cert-hash sha256:<hash>
```

---

## Verify Cluster

```bash
kubectl get nodes
```

Expected output:
```
NAME           STATUS   ROLES           AGE   VERSION
k8s-master-1   Ready    control-plane   ...   v1.32.13
k8s-master-2   Ready    control-plane   ...   v1.32.13
k8s-master-3   Ready    control-plane   ...   v1.32.13
k8s-worker-1   Ready    <none>          ...   v1.32.13
k8s-worker-2   Ready    <none>          ...   v1.32.13
```

```bash
kubectl get pods -A
```

All pods should show `Running` or `Completed`.

---

## Upcoming

- [ ] MetalLB — load balancer using pool 192.168.20.200–220
- [ ] ArgoCD — GitOps deployment pipeline
- [ ] Wazuh — SIEM and security monitoring
- [ ] Ingress controller (nginx)
- [ ] cert-manager — TLS certificate management

---

## Lessons Learned & Automation Goals

| Issue | Manual Fix | Automation Goal |
|-------|-----------|-----------------|
| Cloud-init MAC mismatch on clone | Manual netplan edit per VM | Terraform Proxmox provider provisions VMs with correct MACs |
| SSH password auth blocked by cloud-init | Manual override file edit | Ansible enforces SSH config across all VMs |
| cloud-init overwriting netplan on reboot | Manual disable of cloud-init network config | Baked into Terraform cloud-init user-data |
| kubeadm join token expiry | Regenerate token manually | Ansible playbook automates node join process |

**Phase 2 Priority:** Terraform with the Telmate/Proxmox provider will replace the manual VM cloning and cloud-init configuration process. All K8s node provisioning will be defined as code and version-controlled.
