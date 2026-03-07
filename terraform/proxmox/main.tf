resource "proxmox_vm_qemu" "k8s_worker" {
  for_each = { for vm in var.k8s_workers : vm.name => vm }

  # ── Identity ────────────────────────────────────────────
  name        = each.value.name
  vmid        = each.value.vmid
  target_node = each.value.node
  clone       = var.vm_template
  full_clone  = true

  # ── Hardware ─────────────────────────────────────────────
  cores   = each.value.cores
  memory  = each.value.memory
  sockets = 1
  cpu     = "host"

  disk {
    slot    = 0
    size    = each.value.disk
    type    = "scsi"
    storage = "local-lvm"
  }

  network {
    model  = "virtio"
    bridge = "vmbr0"
    tag    = 20  # VLAN 20 — Lab network
  }

  # ── Cloud-Init ───────────────────────────────────────────
  os_type   = "cloud-init"
  ipconfig0 = "ip=${each.value.ip}/24,gw=${var.gateway}"
  nameserver = var.dns_server
  ciuser    = var.vm_user
  sshkeys   = var.ssh_public_key

  # user_data solves the MAC mismatch issue documented in troubleshooting.md:
  # Cloud-init regenerates netplan on every boot and overwrites static config.
  # We disable cloud-init network management after first boot so netplan
  # retains the correct MAC-matched config permanently.
  user_data = <<-EOF
    #cloud-config
    hostname: ${each.value.name}
    manage_etc_hosts: true

    users:
      - name: ${var.vm_user}
        sudo: ALL=(ALL) NOPASSWD:ALL
        shell: /bin/bash
        ssh_authorized_keys:
          - ${var.ssh_public_key}

    # Disable cloud-init network management after first boot.
    # This prevents the MAC mismatch issue where cloud-init overwrites
    # the netplan config with a stale MAC address on reboot.
    write_files:
      - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
        content: |
          network: {config: disabled}

    # Ensure SSH key-based auth works — override cloud-init SSH defaults
      - path: /etc/ssh/sshd_config.d/99-homelab.conf
        content: |
          PasswordAuthentication no
          PubkeyAuthentication yes

    runcmd:
      - systemctl restart ssh
      - apt-get update -qq
      - apt-get install -y curl apt-transport-https
  EOF

  # ── Lifecycle ────────────────────────────────────────────
  lifecycle {
    ignore_changes = [
      network,    # Prevent Terraform from fighting Proxmox over MAC assignments
    ]
  }

  timeouts {
    create = "10m"
    delete = "5m"
  }
}
