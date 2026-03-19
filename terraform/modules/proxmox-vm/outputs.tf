output "vm_ips" {
  description = "IP addresses of provisioned VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm :
    name => vm.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "vm_ids" {
  description = "VM IDs of provisioned VMs"
  value = {
    for name, vm in proxmox_virtual_environment_vm.vm :
    name => vm.vm_id
  }
}
