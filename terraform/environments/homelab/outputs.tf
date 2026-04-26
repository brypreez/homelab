output "k8s_worker_ips" {
  description = "IP addresses of Terraform-managed K8s worker nodes"
  value       = module.k8s_workers.vm_ips
}

output "k8s_worker_vmids" {
  description = "VM IDs of Terraform-managed K8s worker nodes"
  value       = module.k8s_workers.vm_ids
}
