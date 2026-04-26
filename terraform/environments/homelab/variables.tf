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
  description = "All K8s nodes to provision"
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
      name          = "k8s-master-1"
      vmid          = 201
      ip            = "192.168.20.10"
      cores         = 4
      memory        = 8192
      disk          = "40G"
      node          = "enode-a"
      template_vmid = 9000
    },
    {
      name          = "k8s-master-2"
      vmid          = 202
      ip            = "192.168.20.11"
      cores         = 4
      memory        = 8192
      disk          = "40G"
      node          = "enode-b"
      template_vmid = 9001
    },
    {
      name          = "k8s-master-3"
      vmid          = 203
      ip            = "192.168.20.12"
      cores         = 4
      memory        = 8192
      disk          = "40G"
      node          = "enode-c"
      template_vmid = 9002
    },
    {
      name          = "k8s-worker-1"
      vmid          = 204
      ip            = "192.168.20.20"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-a"
      template_vmid = 9000
    },
    {
      name          = "k8s-worker-2"
      vmid          = 205
      ip            = "192.168.20.21"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-b"
      template_vmid = 9001
    },
    {
      name          = "k8s-worker-3"
      vmid          = 206
      ip            = "192.168.20.22"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-b"
      template_vmid = 9001
    },
    {
      name          = "k8s-worker-4"
      vmid          = 207
      ip            = "192.168.20.23"
      cores         = 4
      memory        = 6144
      disk          = "50G"
      node          = "enode-c"
      template_vmid = 9002
    }
  ]
}
