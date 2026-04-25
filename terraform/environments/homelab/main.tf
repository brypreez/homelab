terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.98.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}

module "k8s_workers" {
  source = "../../modules/proxmox-vm"

  vms            = var.k8s_workers
  vlan_id        = 20
  gateway        = var.gateway
  dns_server     = var.dns_server
  vm_user        = var.vm_user
  ssh_public_key = var.ssh_public_key
}

# - Currently
