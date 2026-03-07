output "k8s_worker_ips" {
  description = "IP addresses of provisioned K8s worker nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k8s_worker :
    name => vm.initialization[0].ip_config[0].ipv4[0].address
  }
}

output "k8s_worker_vmids" {
  description = "VM IDs of provisioned K8s worker nodes"
  value = {
    for name, vm in proxmox_virtual_environment_vm.k8s_worker :
    name => vm.vm_id
  }
}
