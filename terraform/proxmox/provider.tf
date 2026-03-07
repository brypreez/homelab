terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.46"
    }
  }
  required_version = ">= 1.0.0"
}

provider "proxmox" {
  endpoint  = var.proxmox_api_url
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true
}
