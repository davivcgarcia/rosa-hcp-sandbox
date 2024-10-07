############################
# Terraform Configuration
############################
terraform {
  required_version = ">= 1.9.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    rhcs = {
      source  = "terraform-redhat/rhcs"
      version = "~> 1.0"
    }
  }
}

############################
# Provider Configuration
############################

provider "aws" {
  region = var.aws_region
}

provider "rhcs" {
  token = var.rhcs_token
}

// Workaround due lack of native OpenShift provider
data "external" "openshift_context" {
  program = ["bash", "helpers/openshift_create_context.sh", var.rhcs_token, module.hcp.cluster_id, var.openshift_demo_user_login, random_password.password.result]
}

provider "kubectl" {
  host  = data.external.openshift_context.result.server
  token = data.external.openshift_context.result.token
}