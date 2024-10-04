output "rosa_cluster_id" {
  value = module.hcp.cluster_id
}

output "openshift_demo_user_login" {
  value = var.openshift_demo_user_login
}

output "openshift_demo_user_password" {
  value     = random_password.password.result
  sensitive = true
}
