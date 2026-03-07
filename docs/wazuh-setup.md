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

---

## Lessons Learned & Automation Goals

| Issue | Manual Fix | Automation Goal |
|-------|-----------|-----------------|
| IPv4/IPv6 protocol stack mismatch | Manual `opensearch_dashboards.yml` edit | Ansible manages config with explicit IPv4 binding — self-healing |
| Agent version skew after manager upgrade | Manual version check + upgrade sequence | Ansible enforces version parity: manager upgraded first, agents second |
| SSL certs wiped after package upgrade | Manual cert regeneration and deployment | Ansible cert management playbook with idempotent deployment |
| Password reset required after reinstall | Manual `wazuh-passwords-tool.sh` run | Ansible vault stores credentials, playbook handles rotation |
| Agent registration requires manual auth | `agent-auth` per node | Ansible playbook automates bulk agent registration |

**Phase 2 Priority:** Ansible will be the single source of truth for all Wazuh configuration. The first playbook will manage `ossec.conf` across all 8 endpoints and `opensearch_dashboards.yml` on the Wazuh LXC — eliminating configuration drift and providing self-healing infrastructure.

---

## Custom Detection Rules — Kubernetes Control Plane Security

### FIM Configuration for K8s Manifests

Add to `ossec.conf` on all Kubernetes master nodes:

```xml
<syscheck>
  <!-- Default monitored paths -->
  <directories realtime="yes" check_all="yes">/etc,/usr/bin,/usr/sbin</directories>

  <!-- CRITICAL: Kubernetes control plane manifest monitoring -->
  <directories realtime="yes" check_all="yes">/etc/kubernetes/manifests</directories>
</syscheck>
```

This covers: `kube-apiserver.yaml`, `etcd.yaml`, `kube-controller-manager.yaml`, `kube-scheduler.yaml`

### Custom Rule 110005

Add to `/var/ossec/etc/rules/local_rules.xml` on the Wazuh manager:

```xml
<group name="syscheck,k8s_security,">
  <rule id="110005" level="10">
    <if_sid>550</if_sid>
    <field name="file">/etc/kubernetes/manifests</field>
    <description>CRITICAL: K8s Manifest Tampering on $(file)</description>
    <group>syscheck,k8s_security,pci_dss_11.5,gpg13_4.11,</group>
  </rule>
</group>
```

**Compliance mapping:**
- `pci_dss_11.5` — PCI DSS requirement for file integrity monitoring on critical systems
- `gpg13_4.11` — Good Practice Guide 13 control for change detection

**Why level 10:** Modification of K8s control plane manifests is a critical security event — potential indicators include supply chain attacks, unauthorized privilege escalation, and container escape attempts targeting the control plane.

### XML Validation Workflow

Always validate before restarting the manager:

```bash
xmllint --noout /var/ossec/etc/ossec.conf
wazuh-manager --test-config
systemctl restart wazuh-manager
journalctl -u wazuh-manager -n 20
```

Common XML mistakes that cause `Line 0` startup failure:
- Nested `<ossec_config>` tags (only one root container allowed)
- Unclosed tags (use xmllint to find exact line)
- Invalid characters in description strings

---

## Slack Integration — Real-Time Alerting Pipeline

### Architecture

```
K8s Master Node
└── Wazuh Agent (detects FIM event)
    └── Wazuh Manager (matches Rule 110005)
        └── Integration Module
            └── Slack Incoming Webhook
                └── #security-alerts channel
```

### Setup

1. Create a Slack App at api.slack.com/apps
2. Enable Incoming Webhooks
3. Add webhook to `#security-alerts` channel
4. Copy webhook URL

### Secrets Management

The Slack webhook URL is a secret — never commit it to a public repository. This project uses Ansible Vault to store sensitive keys and inject them at deploy time:

```bash
# Store webhook in Ansible Vault — plaintext never touches Git
ansible-vault encrypt_string 'https://hooks.slack.com/services/REAL/URL' \
  --name 'slack_webhook_url' >> ansible/group_vars/wazuh_manager/vault.yml
```

For manual deployments, inject via environment variable:
```bash
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/REAL/URL"
sed "s|<SLACK_WEBHOOK_URL_PLACEHOLDER>|$SLACK_WEBHOOK_URL|g" \
  ossec.conf.template > /var/ossec/etc/ossec.conf
```

> ⚠️ Replace `<SLACK_WEBHOOK_URL_PLACEHOLDER>` at deploy time via Ansible Vault or environment variable injection. Never commit a real webhook URL to version control.

### ossec.conf Integration Block

```xml
<ossec_config>
  <integration>
    <name>slack</name>
    <hook_url><SLACK_WEBHOOK_URL_PLACEHOLDER></hook_url>
    <rule_id>110005</rule_id>
    <alert_format>json</alert_format>
  </integration>
</ossec_config>
```

### Test the Pipeline

```bash
# On any K8s master node — simulate manifest tampering
touch /etc/kubernetes/manifests/test-file
rm /etc/kubernetes/manifests/test-file
```

Slack alert should appear in `#security-alerts` within 30 seconds.
