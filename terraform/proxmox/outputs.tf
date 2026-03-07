output "k8s_worker_ips" {
  description = "IP addresses of provisioned K8s worker nodes"
  value = {
    for name, vm in proxmox_vm_qemu.k8s_worker :
    name => var.k8s_workers[index(var.k8s_workers.*.name, name)].ip
  }
}

output "k8s_worker_vmids" {
  description = "VM IDs of provisioned K8s worker nodes"
  value = {
    for name, vm in proxmox_vm_qemu.k8s_worker :
    name => vm.vmid
  }
}
