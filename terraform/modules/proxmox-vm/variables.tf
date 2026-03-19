variable "vms" {
  description = "List of VM definitions to provision"
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
}

variable "vlan_id" {
  description = "VLAN ID for network device"
  type        = number
  default     = 20
}

variable "gateway" {
  description = "Default gateway for the VLAN"
  type        = string
}

variable "dns_server" {
  description = "DNS server IP"
  type        = string
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
