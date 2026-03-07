resource "proxmox_virtual_environment_vm" "k8s_worker" {
  for_each = { for vm in var.k8s_workers : vm.name => vm }

  node_name = each.value.node
  vm_id     = each.value.vmid
  name      = each.value.name

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores   = each.value.cores
    sockets = 1
    type    = "host"
  }

  memory {
    dedicated = each.value.memory
  }

  disk {
    datastore_id = "local-lvm"
    size         = tonumber(trimsuffix(each.value.disk, "G"))
    interface    = "scsi0"
    file_format  = "raw"
  }

  network_device {
    bridge  = "vmbr0"
    model   = "virtio"
    vlan_id = 20
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = [var.dns_server]
    }

    user_account {
      username = var.vm_user
      keys     = [var.ssh_public_key]
    }
  }

  lifecycle {
    ignore_changes = [network_device]
  }
}
