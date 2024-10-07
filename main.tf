############################
# Amazon VPC
############################
module "vpc" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/vpc"
  version = "~> 1.0"

  name_prefix              = var.environment_name
  vpc_cidr                 = var.openshift_machine_cidr
  availability_zones_count = local.availability_zones_count
}

############################
# ROSA Cluster (HCP)
############################
module "hcp" {
  source  = "terraform-redhat/rosa-hcp/rhcs"
  version = "~> 1.0"

  cluster_name           = var.environment_name
  openshift_version      = var.openshift_release
  aws_billing_account_id = var.aws_billing_account

  // OpenShift Networking
  machine_cidr = module.vpc.cidr_block
  service_cidr = var.openshift_service_cidr
  pod_cidr     = var.openshift_pod_cidr
  host_prefix  = var.openshift_host_prefix

  // OpenShift Machine Pool (Default Worker)
  aws_availability_zones = module.vpc.availability_zones
  aws_subnet_ids = concat(
    module.vpc.private_subnets,
    module.vpc.public_subnets
  )
  replicas             = 1 * length(module.vpc.availability_zones)
  compute_machine_type = var.openshift_default_instance_type

  // STS configuration
  create_account_roles  = true
  create_oidc           = true
  create_operator_roles = true
  account_role_prefix   = var.environment_name
  operator_role_prefix  = var.environment_name

  // Wait for full completion
  wait_for_create_complete            = true
  wait_for_std_compute_nodes_complete = true
}

############################
# ROSA IdP (Htpasswd)
############################
module "htpasswd_idp" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/idp"
  version = "~> 1.0"

  cluster_id = module.hcp.cluster_id
  name       = "htpasswd-idp"
  idp_type   = "htpasswd"
  htpasswd_idp_users = [
    {
      username = var.openshift_demo_user_login
      password = random_password.password.result
    }
  ]
}

resource "random_password" "password" {
  length      = 14
  special     = true
  min_lower   = 1
  min_numeric = 1
  min_special = 1
  min_upper   = 1
}

// Workaround due https://github.com/terraform-redhat/terraform-provider-rhcs/issues/809
resource "null_resource" "cluster_permission_workaround" {
  depends_on = [module.htpasswd_idp]
  provisioner "local-exec" {
    command = <<-EOT
    rosa login --token=${var.rhcs_token}
    rosa grant user dedicated-admin --user=${var.openshift_demo_user_login} --cluster=${var.environment_name}
    EOT
  }
}

############################
# ROSA Machine Pool (Extra)
############################
module "mp-extra" {
  source  = "terraform-redhat/rosa-hcp/rhcs//modules/machine-pool"
  version = "~> 1.0"

  cluster_id        = module.hcp.cluster_id
  openshift_version = var.openshift_release
  count             = length(module.vpc.availability_zones)
  name              = "extra-${count.index}"

  aws_node_pool = {
    instance_type = var.openshift_extra_instance_type
    tags          = {}
  }

  subnet_id = module.vpc.private_subnets[count.index]
  autoscaling = {
    enabled      = true
    min_replicas = 1
    max_replicas = 3
  }
}
