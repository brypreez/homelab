# Troubleshooting Log

Real issues encountered during homelab build — documented with root causes, fixes, and impact statements.

---

## 1. GS308E Management Lockout After Changing Management VLAN

**Symptom:** Changed management VLAN from 1 to 10 on the GS308E. Switch wiped all 802.1Q config and became unreachable on both VLAN 1 and VLAN 10.

**Root Cause:** The GS308E warns that changing the management VLAN resets all 802.1Q configuration. When the switch rebooted on VLAN 10 but no VLAN 10 path existed yet, it became completely unreachable.

**Fix:** Factory reset the switch using the pinhole reset button (hold 10 seconds while powered on). Switch returned to default IP `192.168.0.239`. Reconfigured all VLANs from scratch and left management VLAN on VLAN 1 permanently.

**Impact:** 45-minute outage for all three Proxmox nodes. Full network reconfiguration required. No data loss.

**Lesson:** Never change the management VLAN on a switch mid-configuration. Leave it on VLAN 1 permanently. The router handles inter-VLAN routing — the switch management VLAN is irrelevant to end-to-end connectivity.

**Automation Goal:** Terraform network state management will prevent ad-hoc switch changes. All VLAN modifications will go through version-controlled configuration.

---

## 2. Proxmox Nodes Unreachable After VLAN Migration

**Symptom:** After reconfiguring the ER605 and GS308E to use 802.1Q VLANs, all three Proxmox nodes became unreachable at their `192.168.0.x` addresses.

**Root Cause:** Proxmox nodes had their network config hardcoded in `/etc/network/interfaces` pointing to `192.168.0.x` with no VLAN tagging. The switch ports were now trunk ports sending tagged frames that the nodes weren't configured to handle.

**Fix:** Required physical console access to each node. Three iterations to reach the correct config:
1. Added `nic0.40` subinterface but forgot to update `bridge-ports` — bridge bypassed VLAN subinterface
2. Updated `bridge-ports` to `nic0.40` but `vmbr0` wasn't VLAN-aware — LXC VLAN tags silently dropped
3. Final fix — VLAN-aware bridge on raw NIC with `bridge-vlan-aware yes`

**Impact:** All three Proxmox nodes offline for approximately 2 hours. Required physical access to server rack for each node.

**Lesson:** Always use a VLAN-aware bridge in Proxmox when running multiple VLANs. The bridge must sit on the raw NIC — not a subinterface — with `bridge-vlan-aware yes` so VMs and LXCs can independently tag their own traffic.

**Automation Goal:** Ansible playbook will manage `/etc/network/interfaces` on all Proxmox nodes, preventing configuration drift and enabling automated recovery.

---

## 3. Corosync Cluster Communication Broken After IP Change

**Symptom:** After migrating Proxmox nodes to `192.168.40.x`, the cluster showed nodes as offline despite all nodes being reachable via ping.

**Root Cause:** `/etc/pve/corosync.conf` still referenced the old `192.168.0.x` IPs in `ring0_addr` fields for each node. Corosync stores node IPs statically — it does not auto-discover.

**Fix:** Edited `/etc/pve/corosync.conf` on the primary node, updated all three `ring0_addr` values to `192.168.40.x`, and restarted corosync and pve-cluster on all three nodes.

**Impact:** Cluster quorum lost for approximately 30 minutes. No VMs or LXCs were affected during this window as nodes continued running independently.

**Lesson:** Any time a Proxmox node's IP changes, `corosync.conf` must be manually updated and services restarted on all nodes. This is a common post-migration failure point.

**Automation Goal:** Terraform will provision nodes with static IPs defined at creation time, eliminating the need for post-migration IP changes.

---

## 4. LXC Fails to Start — "Failed to create network device"

**Symptom:** After setting a VLAN tag on an LXC network interface, the LXC failed to start.

**Root Cause:** `vmbr0` did not have `bridge-vlan-aware yes` set. Without VLAN awareness on the bridge, the hypervisor cannot pass tagged frames to LXC network interfaces.

**Fix:** Added `bridge-vlan-aware yes` and `bridge-vids 2-4094` to `vmbr0` in `/etc/network/interfaces`, then ran `ifreload -a`.

**Impact:** Pi-hole and Grafana LXCs offline until bridge was reconfigured. Approximately 20 minutes of DNS and monitoring downtime.

**Lesson:** Any Proxmox bridge that needs to support VLAN-tagged LXCs or VMs must have `bridge-vlan-aware yes` set. This is not the default and is a common oversight when migrating from flat to VLAN-segmented networks.

**Automation Goal:** Ansible playbook will validate bridge configuration on all nodes as part of routine compliance checks.

---

## 5. Pi-hole Not Resolving DNS for Cross-VLAN Clients

**Symptom:** VMs on VLAN 20 (192.168.20.x) could ping Pi-hole at 192.168.10.2 but DNS queries timed out. `dig google.com @192.168.10.2` returned `communications error: timed out`.

**Root Cause:** Pi-hole FTL was configured with `listeningMode = "LOCAL"` in `/etc/pihole/pihole.toml`. This mode implements a subnet check — queries from clients not on the same local subnet as Pi-hole are silently dropped at the application layer, not the firewall.

**Fix:** Changed `listeningMode` in `/etc/pihole/pihole.toml` to `ALL` and restarted pihole-FTL.

**Impact:** 100% DNS resolution failure for all Lab VLAN (VLAN 20) workloads. All Kubernetes VMs fell back to manual `8.8.8.8` entries in `/etc/resolv.conf`, creating a maintenance burden and bypassing Pi-hole filtering entirely.

**Lesson:** Pi-hole v6 defaults to `LOCAL` listening mode. In any multi-VLAN setup this must be changed to `ALL` immediately after installation. The default is designed for single-subnet home use — not enterprise segmented networks.

**Automation Goal:** Ansible playbook will manage `/etc/pihole/pihole.toml` and validate `listeningMode = "ALL"` as part of Pi-hole configuration management.

---

## 6. Cloud-Init SSH Password Authentication Blocked

**Symptom:** SSH returned `Permission denied (publickey)` even after setting `PasswordAuthentication yes` in `/etc/ssh/sshd_config`.

**Root Cause:** Cloud-init drops an override file at `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` containing `PasswordAuthentication no`. Files in `sshd_config.d/` are processed after the main config and take precedence — making changes to the main config file ineffective.

**Fix:** Overwrote the cloud-init SSH override file directly and restarted SSH. Used `qm terminal <vmid>` from the Proxmox host for root console access when sudo was unavailable.

**Impact:** All cloned VMs inaccessible via SSH until the override was corrected. Required direct console access to each VM.

**Lesson:** Always check `/etc/ssh/sshd_config.d/` when SSH config changes don't take effect. Cloud-init actively manages SSH settings via drop-in files that override the main config.

**Automation Goal:** Ansible playbook will manage SSH configuration across all VMs, enforcing key-based authentication and removing password authentication entirely.

---

## 7. Netplan MAC Address Mismatch After VM Clone

**Symptom:** Cloned VMs had no network connectivity. `netplan apply` returned `Cannot find unique matching interface for eth0`.

**Root Cause:** Cloud-init generates netplan config with a `match: macaddress:` field tied to the original VM's MAC. Proxmox assigns a new MAC to each cloned VM — causing netplan to fail to match any interface and silently skip network configuration.

**Fix:** For each cloned VM: retrieved actual MAC via `ip link show`, updated the `macaddress:` field and IP address in `/etc/netplan/50-cloud-init.yaml`, fixed permissions with `chmod 600`, applied with `netplan apply`. Also disabled cloud-init network management to prevent reversion on reboot.

**Impact:** All 4 cloned Kubernetes VMs had no network on first boot. Required console access to each VM to manually correct netplan configuration.

**Lesson:** When cloning cloud-init VMs in Proxmox, always update the MAC address in netplan to match the new VM's actual MAC. Disable cloud-init network management after first-boot configuration with `echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg`.

**Automation Goal:** Terraform Proxmox provider will handle VM provisioning with correct MAC-to-IP mappings from the start, eliminating manual netplan corrections entirely.

---

## 8. Wazuh Dashboard IPv4/IPv6 Protocol Stack Preference Conflict

**Symptom:** `[ConnectionError]: connect ECONNREFUSED ::1:9200` — Wazuh dashboard couldn't connect to the indexer despite both services running and passing health checks.

**Root Cause:** Modern Linux distributions follow RFC 6724, which gives IPv6 higher precedence in the default address selection algorithm. When the dashboard resolved `localhost`, the OS returned `::1` (IPv6 loopback) rather than `127.0.0.1` (IPv4 loopback). The Wazuh Indexer (OpenSearch) was bound strictly to `127.0.0.1` via `network.host`, creating a protocol stack mismatch. All services reported healthy — the failure existed entirely in the network layer handoff between components, making it particularly difficult to diagnose from service status alone.

**Fix:** Updated `/etc/wazuh-dashboard/opensearch_dashboards.yml`:
```yaml
opensearch.hosts: ["https://127.0.0.1:9200"]
opensearch.ssl.verificationMode: none
```

**Impact:** Wazuh dashboard completely inaccessible. Zero visibility into security events across all 8 monitored endpoints until resolved.

**Lesson:** Never rely on `localhost` hostname resolution in service-to-service communication on dual-stack Linux systems. Always bind and connect using explicit IP addresses. This class of failure is insidious because all individual services report healthy — the fault lives in the OS network stack preference, not any single service.

**Automation Goal:** Ansible playbook will manage `opensearch_dashboards.yml` configuration, ensuring `opensearch.hosts` always uses explicit IPv4 addresses and providing self-healing capability if configuration drift occurs.

---

## 9. Wazuh Agent Version Mismatch

**Symptom:** Agent registration failed with `Agent version must be lower or equal to manager version`.

**Root Cause:** The Wazuh apt repository had released version 4.14.3 by the time agents were installed, while the manager was still running 4.10.3 from the initial installation. Agents cannot be newer than the manager.

**Fix:** Upgraded the manager, indexer, and dashboard to 4.14.3 via `apt upgrade`. Regenerated SSL certificates after upgrade as the upgrade process removed the existing cert files.

**Impact:** All 8 agents unable to register or send events to the manager until the version mismatch was resolved.

**Lesson:** When deploying Wazuh in a multi-component environment, always install agents last and pin versions explicitly to match the manager. Consider using `apt-mark hold wazuh-manager` to prevent unintended manager upgrades that could create version skew.

**Automation Goal:** Ansible playbook will manage Wazuh agent version across all endpoints, ensuring version parity with the manager and automating the upgrade sequence (manager first, agents second).
