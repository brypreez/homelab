# Troubleshooting Log

Real issues encountered during homelab build — documented with root causes and fixes.

---

## 1. GS308E Management Lockout After Changing Management VLAN

**Symptom:** Changed management VLAN from 1 to 10 on the GS308E. Switch wiped all 802.1Q config and became unreachable on both VLAN 1 and VLAN 10.

**Root Cause:** The GS308E warns that changing the management VLAN resets all 802.1Q configuration. When the switch rebooted on VLAN 10 but no VLAN 10 path existed yet, it became completely unreachable.

**Fix:** Factory reset the switch using the pinhole reset button (hold 10 seconds while powered on). Switch returned to default IP `192.168.0.239`.

**Lesson:** Never change the management VLAN on a switch mid-configuration. Leave it on VLAN 1 permanently and pass VLAN 1 tagged through the router trunk instead. The router handles inter-VLAN routing anyway.

---

## 2. Proxmox Nodes Unreachable After VLAN Migration

**Symptom:** After reconfiguring the ER605 and GS308E to use 802.1Q VLANs, all three Proxmox nodes became unreachable. They had static IPs on `192.168.0.x` but the switch ports were now trunk ports expecting tagged traffic.

**Root Cause:** Proxmox nodes had their network config hardcoded in `/etc/network/interfaces` pointing to `192.168.0.x` with no VLAN tagging. The switch was now sending tagged frames that the nodes weren't configured to handle.

**Fix:** Required physical console access (monitor + keyboard) to each node. Edited `/etc/network/interfaces` on each to:
1. First attempt — added `nic0.40` subinterface but forgot to change `bridge-ports` from `nic0` to `nic0.40`. Bridge bypassed the VLAN subinterface entirely.
2. Second attempt — changed `bridge-ports` to `nic0.40` but discovered `vmbr0` wasn't VLAN-aware, so LXCs with VLAN tags couldn't communicate.
3. Final fix — switched to a VLAN-aware bridge on the raw NIC:

```
auto vmbr0
iface vmbr0 inet manual
        bridge-ports nic0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

auto vmbr0.40
iface vmbr0.40 inet static
        address 192.168.40.1X/24
        gateway 192.168.40.1
```

**Lesson:** Always use a VLAN-aware bridge in Proxmox when running multiple VLANs. The bridge must sit on the raw NIC with `bridge-vlan-aware yes` so VMs and LXCs can tag their own traffic.

---

## 3. Corosync Cluster Communication Broken After IP Change

**Symptom:** After migrating Proxmox nodes to `192.168.40.x`, the Proxmox cluster showed nodes as offline even though all nodes were reachable via ping.

**Root Cause:** `/etc/pve/corosync.conf` still had the old `192.168.0.x` IPs in the `ring0_addr` fields for each node.

**Fix:** Edited `/etc/pve/corosync.conf` on enode-c and updated all three `ring0_addr` values to the new `192.168.40.x` IPs. Then restarted corosync and pve-cluster on all three nodes:

```bash
systemctl restart corosync
systemctl restart pve-cluster
```

Verified with `pvecm status` — all 3 nodes showing quorate.

**Lesson:** Corosync stores node IPs statically in its config file. Any time a node's IP changes, `corosync.conf` must be updated manually and the service restarted on all nodes.

---

## 4. LXC Fails to Start with "Failed to create network device"

**Symptom:** After setting a VLAN tag on an LXC's network interface, the LXC failed to start with:
```
lxc_create_network_priv: Success - Failed to create network device
TASK ERROR: startup for container '100' failed
```

**Root Cause:** The Proxmox bridge (`vmbr0`) did not have `bridge-vlan-aware yes` set. Without VLAN awareness on the bridge, LXCs cannot use VLAN tags on their network interfaces.

**Fix:** Added `bridge-vlan-aware yes` and `bridge-vids 2-4094` to the `vmbr0` bridge config in `/etc/network/interfaces`, then ran `ifreload -a`.

**Lesson:** Any Proxmox bridge that needs to support VLAN-tagged LXCs or VMs must have `bridge-vlan-aware yes` set. This is not the default.

---

## 5. Pi-hole Not Resolving DNS for Cross-VLAN Clients

**Symptom:** VMs on VLAN 20 (192.168.20.x) could ping Pi-hole at 192.168.10.2 but DNS queries timed out. `dig google.com @192.168.10.2` returned `communications error: timed out`.

**Root Cause:** Pi-hole's FTL (DNS engine) was configured with `listeningMode = "LOCAL"` in `/etc/pihole/pihole.toml`. This mode only responds to clients on the same local subnet. VMs on VLAN 20 were being silently dropped.

**Fix:** Changed `listeningMode` in `/etc/pihole/pihole.toml`:
```
listeningMode = "ALL"
```

Then restarted Pi-hole FTL:
```bash
systemctl restart pihole-FTL
```

**Lesson:** Pi-hole v6 defaults to `LOCAL` listening mode. In any multi-VLAN setup, this must be changed to `ALL` so Pi-hole responds to DNS queries from all subnets.

---

## 6. Cloud-Init Overwriting SSH Config — Password Auth Blocked

**Symptom:** After cloning Ubuntu VMs from a cloud-init template, SSH returned `Permission denied (publickey)` even after setting `PasswordAuthentication yes` in `/etc/ssh/sshd_config`.

**Root Cause:** Cloud-init drops its own SSH config file at `/etc/ssh/sshd_config.d/60-cloudimg-settings.conf` containing:
```
PasswordAuthentication no
```

This file overrides the main `sshd_config` since files in `sshd_config.d/` are processed after the main config.

**Fix:** Overwrite the cloud-init SSH override file:
```bash
echo "PasswordAuthentication yes" > /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
systemctl restart ssh
```

Or access via Proxmox host using `qm terminal <vmid>` to run commands as root when sudo is not available.

**Lesson:** Always check `/etc/ssh/sshd_config.d/` when SSH config changes don't take effect. Cloud-init actively manages SSH settings and its override files take precedence.

---

## 7. Netplan MAC Address Mismatch After VM Clone

**Symptom:** Cloned VMs had no network connectivity. `netplan apply` returned `Cannot find unique matching interface for eth0`.

**Root Cause:** Cloud-init generates netplan config with a `match: macaddress:` field tied to the original VM's MAC address. When cloning, Proxmox assigns a new MAC address to the cloned VM, causing netplan to fail to match any interface.

**Fix:** For each cloned VM:
1. Get the actual MAC: `ip link show`
2. Edit `/etc/netplan/50-cloud-init.yaml`
3. Update `macaddress:` to the new MAC
4. Update the IP address to the correct one for that VM
5. Fix permissions: `chmod 600 /etc/netplan/50-cloud-init.yaml`
6. Apply: `netplan apply`

Also prevent cloud-init from overwriting the config on reboot:
```bash
echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
```

**Lesson:** When cloning cloud-init VMs in Proxmox, always update the MAC address in the netplan config to match the new VM's actual MAC. Cloud-init does not automatically regenerate this on clone.

---

## 8. ER605 "Current VLAN has been used" Error

**Symptom:** When trying to add VLAN 20, 30, or 40 as full network interfaces in the ER605 Network List, got error: "Current VLAN has been used, please enter again."

**Root Cause:** The VLANs were already created in the VLAN List (for trunk port assignment) but not yet as full network interfaces. The ER605 treats these as conflicting entries.

**Fix:** Delete the VLAN entries from the VLAN List first, then recreate them through Network List → Add. Creating via Network List automatically creates both the VLAN entry and the network interface together.

**Lesson:** On the ER605, VLANs should be created through the Network List (not the VLAN List) if you want them to have IP interfaces and DHCP. The VLAN List is only for port-level tagging configuration.
