variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://192.168.40.10:8006/api2/json"
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
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

variable "k8s_workers" {
  description = "List of K8s worker node definitions"
  type = list(object({
    name          = string
    vmid          = number
    ip            = string
    cores         = number
    memory        = number
    disk          = string
    node          = string
    template_vmid = number
  }))
  default = [
    {
      name          = "k8s-worker-3"
      vmid          = 205
      ip            = "192.168.20.22"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-b"
      template_vmid = 9001
    },
    {
      name          = "k8s-worker-4"
      vmid          = 206
      ip            = "192.168.20.23"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-c"
      template_vmid = 9002
    }
  ]
}
