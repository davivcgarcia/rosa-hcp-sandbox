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
    interpreter = ["/bin/bash"]
    command     = <<-EOT
    rosa login --token=${var.rhcs_token}
    rosa grant user cluster-admin --user=${var.openshift_demo_user_login} --cluster=${var.environment_name}
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

############################
# OpenShift Sample App (OSToy)
# https://www.rosaworkshop.io/ostoy/3-lab_overview/#ostoy-application-diagram
############################

resource "kubectl_manifest" "ostoy-ns" {
  yaml_body = <<-EOT
  apiVersion: project.openshift.io/v1
  kind: Project
  metadata:
    name: ostoy
    annotations:
      openshift.io/description: "Sample project for Hello World"
      openshift.io/display-name: "Hello World, from OpenShift!" 
  EOT
}

resource "kubectl_manifest" "ostoy-backend-deploy" {
  depends_on = [kubectl_manifest.ostoy-ns]
  wait_for_rollout = false
  yaml_body  = <<-EOT
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: ostoy-microservice
    namespace: ostoy
    labels:
      app: ostoy
  spec:
    selector:
      matchLabels:
        app: ostoy-microservice
    replicas: 1
    template:
      metadata:
        labels:
          app: ostoy-microservice
      spec:
        nodeSelector:
          kubernetes.io/arch: amd64
        containers:
        - name: ostoy-microservice
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
            capabilities:
              drop:
              - ALL
          image: quay.io/ostoylab/ostoy-microservice:1.5.0
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 8080
            protocol: TCP
          resources:
            requests:
              memory: "128Mi"
              cpu: "50m"
            limits:
              memory: "256Mi"
              cpu: "100m"
  EOT
}

resource "kubectl_manifest" "ostoy-backend-svc" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: v1
  kind: Service
  metadata:
    name: ostoy-microservice-svc
    namespace: ostoy
    labels:
      app: ostoy-microservice
  spec:
    type: ClusterIP
    ports:
      - port: 8080
        targetPort: 8080
        protocol: TCP
    selector:
      app: ostoy-microservice
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-pvc" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: v1
  kind: PersistentVolumeClaim
  metadata:
    name: ostoy-pvc
    namespace: ostoy
  spec:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 1Gi
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-deploy" {
  depends_on = [kubectl_manifest.ostoy-ns]
  wait_for_rollout = false
  yaml_body  = <<-EOT
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: ostoy-frontend
    namespace: ostoy
    labels:
      app: ostoy
  spec:
    selector:
      matchLabels:
        app: ostoy-frontend
    strategy:
      type: Recreate
    replicas: 1
    template:
      metadata:
        labels:
          app: ostoy-frontend
      spec:
        nodeSelector:
          kubernetes.io/arch: amd64
        containers:
        - name: ostoy-frontend
          securityContext:
            allowPrivilegeEscalation: false
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
            capabilities:
              drop:
              - ALL
          image: quay.io/ostoylab/ostoy-frontend:1.6.0
          imagePullPolicy: IfNotPresent
          ports:
          - name: ostoy-port
            containerPort: 8080
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "200m"
          volumeMounts:
          - name: configvol
            mountPath: /var/config
          - name: secretvol
            mountPath: /var/secret
          - name: datavol
            mountPath: /var/demo_files
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          env:
          - name: ENV_TOY_SECRET
            valueFrom:
              secretKeyRef:
                name: ostoy-secret-env
                key: ENV_TOY_SECRET
          - name: MICROSERVICE_NAME
            value: OSTOY_MICROSERVICE_SVC
          - name: NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
        volumes:
          - name: configvol
            configMap:
              name: ostoy-configmap-files
          - name: secretvol
            secret:
              defaultMode: 420
              secretName: ostoy-secret
          - name: datavol
            persistentVolumeClaim:
              claimName: ostoy-pvc
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-svc" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: v1
  kind: Service
  metadata:
    name: ostoy-frontend-svc
    namespace: ostoy
    labels:
      app: ostoy-frontend
  spec:
    type: ClusterIP
    ports:
      - port: 8080
        targetPort: ostoy-port
        protocol: TCP
        name: ostoy
    selector:
      app: ostoy-frontend
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-route" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    name: ostoy-route
    namespace: ostoy
  spec:
    to:
      kind: Service
      name: ostoy-frontend-svc
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-secret-env" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: v1
  kind: Secret
  metadata:
    name: ostoy-secret-env
    namespace: ostoy
  type: Opaque
  data:
    ENV_TOY_SECRET: VGhpcyBpcyBhIHRlc3Q=
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-cm" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  kind: ConfigMap
  apiVersion: v1
  metadata:
    name: ostoy-configmap-files
    namespace: ostoy
  data:
    config.json:  '{ "default": "123" }'
  EOT
}

resource "kubectl_manifest" "ostoy-frontend-secret-file" {
  depends_on = [kubectl_manifest.ostoy-ns]
  yaml_body  = <<-EOT
  apiVersion: v1
  kind: Secret
  metadata:
    name: ostoy-secret
    namespace: ostoy
  data:
    secret.txt: VVNFUk5BTUU9bXlfdXNlcgpQQVNTV09SRD1AT3RCbCVYQXAhIzYzMlk1RndDQE1UUWsKU01UUD1sb2NhbGhvc3QKU01UUF9QT1JUPTI1
  type: Opaque
  EOT
}
