############################
# Terraform Configuration
############################

output "openshift_cluster_id" {
  value = module.hcp.cluster_id
}

output "openshift_api_url" {
  value = data.external.openshift_context.result.server
}

output "openshift_demo_user_login" {
  value = var.openshift_demo_user_login
}

output "openshift_demo_user_password" {
  value     = random_password.password.result
  sensitive = true
}
