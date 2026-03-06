# Network Setup Guide

Complete VLAN configuration for the homelab using TP-Link ER605 and Netgear GS308E.

---

## Physical Layout

```
Internet
    │
    ▼
TP-Link ER605 (Router/Firewall)
    │  Port 1 → WAN (internet)
    │  Port 2 → VLAN 10 untagged (workstation)
    │  Port 3 → Trunk to GS308E (all VLANs tagged)
    │
    ▼
Netgear GS308E (Managed Switch)
    │  Port 1 → enode-a (trunk)
    │  Port 2 → enode-b (trunk)
    │  Port 3 → enode-c (trunk)
    │  Port 4 → ER605 (trunk)
    │  Ports 5-8 → unused (VLAN 1 default)
```

---

## VLAN Design

| VLAN ID | Name | Gateway | DHCP Range | Notes |
|---------|------|---------|------------|-------|
| 1 | Default | — | — | Switch management only |
| 10 | Management | 192.168.10.1 | .100–.200 | Workstation, Pi-hole |
| 20 | Lab | 192.168.20.1 | .100–.199 | Kubernetes VMs |
| 30 | IoT | 192.168.30.1 | .100–.200 | IoT devices |
| 40 | Servers | 192.168.40.1 | .100–.200 | Proxmox nodes |

> **Note:** 192.168.20.200–220 is reserved for MetalLB load balancer pool.

---

## ER605 Configuration

### VLAN List

| VLAN ID | Name | Ports |
|---------|------|-------|
| 1 | vlan1 | 3(TAG) 4(UNTAG) 5(UNTAG) |
| 10 | Management | 2(UNTAG) 3(TAG) |
| 20 | Lab | 3(TAG) |
| 30 | IoT | 3(TAG) |
| 40 | Servers | 3(TAG) |
| 4094 | WAN | 1(UNTAG) |

> Port 3 is the trunk to the GS308E carrying all VLANs tagged.
> VLAN 1 is kept tagged on port 3 so the switch management UI remains reachable.

### Network Interfaces

Each VLAN has a corresponding network interface with DHCP enabled:

| Interface | VLAN | IP | DNS |
|-----------|------|----|-----|
| LAN1 | 1 | 192.168.0.1 | 192.168.10.2 |
| Management | 10 | 192.168.10.1 | 192.168.10.2 |
| Lab | 20 | 192.168.20.1 | 192.168.10.2 |
| IoT | 30 | 192.168.30.1 | 192.168.10.2 |
| Servers | 40 | 192.168.40.1 | 192.168.10.2 |

All VLANs use Pi-hole (192.168.10.2) as primary DNS.

### Firewall Rules (Access Control)

| Rule | Policy | Source | Destination | Purpose |
|------|--------|--------|-------------|---------|
| Block_IoT_to_Lab | Block | IoT | Lab | Isolate IoT from K8s network |
| Allow_DNS_to_Pihole | Allow | Lab | Management | K8s VMs can reach Pi-hole |

---

## GS308E Configuration

**Mode:** Basic 802.1Q VLAN

### Port Configuration

| Port | Device | Mode | VLANs |
|------|--------|------|-------|
| 1 | enode-a | Trunk | All (auto) |
| 2 | enode-b | Trunk | All (auto) |
| 3 | enode-c | Trunk | All (auto) |
| 4 | ER605 | Trunk | All (auto) |
| 5–8 | Unused | Access | VLAN 1 |

> In Basic 802.1Q mode, trunk ports automatically carry all VLANs — no manual per-VLAN assignment needed.

> **Important:** Leave the Management VLAN on the switch set to VLAN 1. Changing it will cause a lockout requiring a factory reset.

---

## Proxmox Network Configuration

Each Proxmox node uses a VLAN-aware bridge to carry all VLANs to VMs and LXCs.

### `/etc/network/interfaces` (all nodes)

```
auto lo
iface lo inet loopback

iface nic0 inet manual

auto vmbr0
iface vmbr0 inet manual
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

auto vmbr0.40
iface vmbr0.40 inet static
        address 192.168.40.1X/24     # .10, .11, or .12 per node
        gateway 192.168.40.1

source /etc/network/interfaces.d/*
```

**Key points:**
- `vmbr0` is a VLAN-aware bridge on the raw NIC — carries all VLANs
- `vmbr0.40` is a VLAN subinterface — Proxmox's own management IP on VLAN 40
- VMs/LXCs use `vmbr0` with a VLAN tag set in their network config

### Static IP Reservations (ER605)

| Host | MAC | IP |
|------|-----|----|
| enode-a | C8:5A:CF:A4:75:FE | 192.168.40.10 |
| enode-b | 50:81:40:92:9F:E5 | 192.168.40.11 |
| enode-c | 80:E8:2C:31:BD:F2 | 192.168.40.12 |
| k8s-master-1 | bc:24:11:7a:19:26 | 192.168.20.10 |
| k8s-master-2 | bc:24:11:35:d8:26 | 192.168.20.11 |
| k8s-master-3 | bc:24:11:94:b7:9c | 192.168.20.12 |
| k8s-worker-1 | bc:24:11:3c:25:1c | 192.168.20.20 |
| k8s-worker-2 | bc:24:11:ae:00:12 | 192.168.20.21 |

---

## Pi-hole DNS Configuration

Pi-hole runs on LXC 100 at `192.168.10.2` and serves DNS for all VLANs.

**Key settings:**
- Listening mode: `ALL` (accepts queries from all subnets)
- Upstream DNS: Cloudflare (1.1.1.1)
- All ER605 VLAN interfaces point to 192.168.10.2 as primary DNS

> Default listening mode is `LOCAL` which only responds to the local subnet.
> Must be changed to `ALL` in `/etc/pihole/pihole.toml` for cross-VLAN DNS to work.

---

## Lessons Learned & Automation Goals

| Issue | Manual Fix | Automation Goal |
|-------|-----------|-----------------|
| GS308E management VLAN lockout | Factory reset + full reconfiguration | Terraform network state management |
| Proxmox bridge not VLAN-aware | Manual `/etc/network/interfaces` edit | Ansible playbook for bridge config validation |
| Corosync IPs not updated after migration | Manual `corosync.conf` edit | Terraform provisions nodes with static IPs from day one |
| Pi-hole `LOCAL` listening mode | Manual `pihole.toml` edit | Ansible manages Pi-hole configuration |

**Phase 2 Priority:** Ansible inventory and playbooks will replace all manual network configuration steps documented above, enabling repeatable, auditable infrastructure changes.
