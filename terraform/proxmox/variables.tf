# ============================================================
# Proxmox Connection — values live in terraform.tfvars (gitignored)
# ============================================================
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.40.10:8006/api2/json"
}

variable "proxmox_user" {
  description = "Proxmox API user (e.g. root@pam)"
  type        = string
  sensitive   = true
}

variable "proxmox_password" {
  description = "Proxmox API password"
  type        = string
  sensitive   = true
}

# ============================================================
# VM Configuration
# ============================================================
variable "proxmox_node" {
  description = "Proxmox node to deploy VMs on"
  type        = string
  default     = "enode-a"
}

variable "vm_template" {
  description = "Cloud-init template name in Proxmox"
  type        = string
  default     = "ubuntu-22.04-template"
}

variable "vm_user" {
  description = "Default user for cloud-init"
  type        = string
  default     = "brp"
}

variable "ssh_public_key" {
  description = "SSH public key to inject into VMs"
  type        = string
  sensitive   = true
}

# ============================================================
# K8s Worker Nodes — scale by adding entries to this list
# ============================================================
variable "k8s_workers" {
  description = "List of K8s worker node definitions"
  type = list(object({
    name    = string
    vmid    = number
    ip      = string
    cores   = number
    memory  = number
    disk    = string
    node    = string
  }))
  default = [
    {
      name   = "k8s-worker-3"
      vmid   = 205
      ip     = "192.168.20.22"
      cores  = 4
      memory = 8192
      disk   = "50G"
      node   = "enode-b"
    },
    {
      name   = "k8s-worker-4"
      vmid   = 206
      ip     = "192.168.20.23"
      cores  = 4
      memory = 8192
      disk   = "50G"
      node   = "enode-c"
    }
  ]
}

variable "gateway" {
  description = "Default gateway for VLAN 20"
  type        = string
  default     = "192.168.20.1"
}

variable "dns_server" {
  description = "Pi-hole DNS server"
  type        = string
  default     = "192.168.10.2"
}
