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