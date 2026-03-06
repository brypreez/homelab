# Wazuh SIEM/XDR Setup

Wazuh 4.14.3 single-node deployment on a dedicated LXC monitoring all Proxmox nodes and Kubernetes VMs.

---

## Architecture

```
LXC 102 — Wazuh Server (192.168.40.20, VLAN 40)
├── wazuh-indexer  (OpenSearch, port 9200)
├── wazuh-manager  (SIEM engine, ports 1514/1515)
└── wazuh-dashboard (Web UI, port 443)

Agents (8 endpoints):
├── enode-a  (192.168.40.10)
├── enode-b  (192.168.40.11)
├── enode-c  (192.168.40.12)
├── k8s-master-1 (192.168.20.10)
├── k8s-master-2 (192.168.20.11)
├── k8s-master-3 (192.168.20.12)
├── k8s-worker-1 (192.168.20.20)
└── k8s-worker-2 (192.168.20.21)
```

---

## LXC Specs

| Setting | Value |
|---------|-------|
| CT ID | 102 |
| Hostname | wazuh |
| OS | Ubuntu 22.04 LTS |
| CPU | 4 cores |
| RAM | 8GB |
| Disk | 50GB |
| IP | 192.168.40.20/24 |
| Gateway | 192.168.40.1 |
| DNS | 192.168.10.2 |
| VLAN | 40 |

---

## Server Installation

### 1. Download installer

```bash
curl -sO https://packages.wazuh.com/4.10/wazuh-install.sh
curl -sO https://packages.wazuh.com/4.10/config.yml
```

### 2. Configure nodes

Edit `config.yml`:

```yaml
nodes:
  indexer:
    - name: wazuh-indexer
      ip: 192.168.40.20
  server:
    - name: wazuh-manager
      ip: 192.168.40.20
  dashboard:
    - name: wazuh-dashboard
      ip: 192.168.40.20
```

### 3. Run installer

```bash
bash wazuh-install.sh -a
```

The installer outputs credentials on completion — save immediately to a password manager.

### 4. Upgrade to latest version

```bash
apt update
apt install wazuh-manager wazuh-indexer wazuh-dashboard -y
```

---

## Critical Troubleshooting — IPv4/IPv6 Conflict

After upgrading from 4.10.3 to 4.14.3, the dashboard failed to connect to the indexer with:

```
[ConnectionError]: connect ECONNREFUSED ::1:9200
```

**Root Cause:** Dashboard resolved `localhost` to IPv6 `::1` but indexer was bound to IPv4 `127.0.0.1`.

**Fix in `/etc/wazuh-dashboard/opensearch_dashboards.yml`:**

```yaml
opensearch.hosts: ["https://127.0.0.1:9200"]
opensearch.ssl.verificationMode: none
```

**Verify indexer binding:**

```bash
grep "network.host" /etc/wazuh-indexer/opensearch.yml
# Should return: network.host: "127.0.0.1"
```

---

## Certificate Management

After reinstalls or upgrades, certificates may need to be regenerated:

```bash
# Copy config to tools directory
cp ~/config.yml /usr/share/wazuh-indexer/plugins/opensearch-security/tools/config.yml

# Regenerate certs
bash /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certs-tool.sh -A

# Deploy dashboard certs
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/wazuh-dashboard.pem /etc/wazuh-dashboard/certs/dashboard.pem
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/wazuh-dashboard-key.pem /etc/wazuh-dashboard/certs/dashboard-key.pem
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/root-ca.pem /etc/wazuh-dashboard/certs/root-ca.pem
chmod 500 /etc/wazuh-dashboard/certs
chmod 400 /etc/wazuh-dashboard/certs/*
chown -R wazuh-dashboard:wazuh-dashboard /etc/wazuh-dashboard/certs

# Deploy indexer certs
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/wazuh-indexer.pem /etc/wazuh-indexer/certs/indexer.pem
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/wazuh-indexer-key.pem /etc/wazuh-indexer/certs/indexer-key.pem
cp /usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-certificates/root-ca.pem /etc/wazuh-indexer/certs/root-ca.pem
chmod 500 /etc/wazuh-indexer/certs
chmod 400 /etc/wazuh-indexer/certs/*
chown -R wazuh-indexer:wazuh-indexer /etc/wazuh-indexer/certs
```

---

## Password Reset

```bash
/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh -a
```

Note the new admin password and update `/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml` accordingly.

---

## Agent Installation

Run on each endpoint to be monitored:

```bash
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import && chmod 644 /usr/share/keyrings/wazuh.gpg
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list
apt update
apt install wazuh-agent -y
sed -i 's/MANAGER_IP/192.168.40.20/' /var/ossec/etc/ossec.conf
systemctl enable wazuh-agent
systemctl start wazuh-agent
```

### Register agent manually if needed

```bash
/var/ossec/bin/agent-auth -m 192.168.40.20
```

> **Note:** Agent version must be equal to or lower than manager version. If agents are newer, upgrade the manager first.

---

## Active Monitoring

| Capability | Status |
|-----------|--------|
| CIS Ubuntu 22.04 Benchmark | ✅ Active |
| File Integrity Monitoring | ✅ Active |
| Vulnerability Detection | ✅ Active |
| Real-time Alerting | ✅ Active |
| Custom Dashboards | ✅ Active |

**Custom Dashboards:**
- Security Noise Map — identifies which endpoints generate the most security events
- Top 5 Attacker IPs — tracks external IPs actively probing the infrastructure

---

## Upcoming

- [ ] Kubernetes Audit Logging → Wazuh pipeline
- [ ] Ansible playbook for automated agent deployment and ossec.conf management
- [ ] Alert tuning — reduce false positives on K8s nodes
- [ ] Integration with Grafana for unified observability
