# ROSA HCP Sandbox

This repository contains **not production-ready** automation to provision Red Hat OpenShift Services on AWS (ROSA) clusters using Hosted Control-Plane (HCP) mode. The automation is based on Terraform, and uses Red Hat official providers and modules to configure the necessary Amazon Web Services (AWS) resources.

## Prerequisites

You will need the following CLI tools:

- [terraform](https://developer.hashicorp.com/terraform/install)
- [jq](https://jqlang.github.io/jq/)
- [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [rosa/oc cli](https://docs.openshift.com/rosa/rosa_install_access_delete_clusters/rosa_getting_started_iam/rosa-installing-rosa.html)

Also, the `aws` CLI must be already configured, with the proper credentials associated with the AWS Account to be used with ROSA.

## Usage

1. Clone this repository, initialize Terraform:

```bash
git clone https://github.com/davivcgarcia/rosa-hcp-sandbox.git
cd rosa-hcp-sandbox/
terraform init
```

2. Validate if the input variables are good for your lab environment:

```bash
cat rosa-hcp-sandbox/variables.tf
```

3. Access Red Hat Hybrid Console and copy your authentication token:

[https://console.redhat.com/openshift/token/rosa](https://console.redhat.com/openshift/token/rosa)

4. Execute `terraform apply`, passing the token as parameter:

```bash
terraform apply -var "rhcs_token=<TOKEN HERE>"
```

5. After deployment, login to ROSA cluster with demo user (dedicated-admin) created using the following command:

```bash
ROSA_API_URL=$(terraform output -raw openshift_api_url)
ROSA_USERNAME=$(terraform output -raw openshift_demo_user_login)
ROSA_USER_PASSWORD=$(terraform output -raw openshift_demo_user_password)

oc login $ROSA_API_URL -u $ROSA_USERNAME -p $ROSA_USER_PASSWORD
```

6. To destroy the environment, use the following:

```bash
terraform destroy
```
