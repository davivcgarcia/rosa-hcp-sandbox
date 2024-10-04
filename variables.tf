############################
# Input Variables
############################

variable "environment_name" {
  type    = string
  default = "rosa-hcp-lab"
}

variable "aws_region" {
  type    = string
  default = "eu-central-1"
}

// AWS Account used for internal HCP billing
variable "aws_billing_account" {
  type    = string
  default = "223360971201"
}

variable "openshift_release" {
  type    = string
  default = "4.16.14"
}

// Prefix that will be used for VPC and Subnets
variable "openshift_machine_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "openshift_service_cidr" {
  type    = string
  default = "172.30.0.0/16"
}

variable "openshift_pod_cidr" {
  type    = string
  default = "10.128.0.0/14"
}

variable "openshift_host_prefix" {
  type    = number
  default = 23
}

variable "openshift_default_instance_type" {
  type = string
  default = "m6g.xlarge"
}

variable "openshift_demo_user_login" {
  type    = string
  default = "demo-user"
}

// Required to be inserted manually due short expiration
variable "rhcs_token" {
  type = string
}