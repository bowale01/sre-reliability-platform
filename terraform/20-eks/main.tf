# ---------------------------------------------------------------------------
# EKS cluster + managed node group.
#
# Reads VPC/subnet IDs from the 10-foundation layer via remote state.
# Enables IRSA (IAM Roles for Service Accounts) so workloads like the AWS Load
# Balancer Controller and the Datadog Agent can assume scoped IAM roles.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }

  backend "s3" {
    key = "20-eks/terraform.tfstate"
    # bucket         = "<from 00-remote-state output>"
    # dynamodb_table = "<from 00-remote-state output>"
    # region         = "us-east-1"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "20-eks"
    }
  }
}

# Pull networking from the foundation layer's state.
data "terraform_remote_state" "foundation" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "10-foundation/terraform.tfstate"
    region = var.aws_region
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  cluster_endpoint_public_access = true
  enable_irsa                    = true

  vpc_id     = data.terraform_remote_state.foundation.outputs.vpc_id
  subnet_ids = data.terraform_remote_state.foundation.outputs.private_subnet_ids

  # Core addons. coredns/kube-proxy/vpc-cni/ebs-csi are managed by EKS.
  cluster_addons = {
    coredns                = { most_recent = true }
    kube-proxy             = { most_recent = true }
    vpc-cni                = { most_recent = true }
    aws-ebs-csi-driver     = { most_recent = true }
  }

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  # Small, stable "system" node group. It only needs to run cluster-critical
  # workloads: Karpenter itself, CoreDNS, the Datadog cluster agent, the ALB
  # controller, ArgoCD, etc. Karpenter provisions all APPLICATION capacity
  # just-in-time, so this group stays small and does not autoscale with traffic.
  eks_managed_node_groups = {
    system = {
      min_size       = var.system_node_min_size
      max_size       = var.system_node_max_size
      desired_size   = var.system_node_desired_size
      instance_types = var.system_node_instance_types
      capacity_type  = "ON_DEMAND"
      labels = {
        workload = "system"
      }
      # Keep application pods off the system group; they land on Karpenter nodes.
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  # Grant the applying identity cluster-admin so kubectl/helm works immediately.
  enable_cluster_creator_admin_permissions = true

  # Node security group discovery tag so Karpenter's EC2NodeClass can find the
  # SG to attach to the nodes it launches.
  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    # Karpenter discovery tag (also applied to subnets in 10-foundation).
    "karpenter.sh/discovery"                    = var.cluster_name
  }
}

# --------------------------------------------------------------------------- #
# Kubernetes & Helm providers wired to the new cluster.
# --------------------------------------------------------------------------- #
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# --------------------------------------------------------------------------- #
# AWS Load Balancer Controller (provisions the ALB for the Ingress).
# IRSA role is created by the eks module's helper.
# --------------------------------------------------------------------------- #
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.44"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "helm_release" "lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.lb_controller_irsa.iam_role_arn
  }
  set {
    name  = "region"
    value = var.aws_region
  }
  set {
    name  = "vpcId"
    value = data.terraform_remote_state.foundation.outputs.vpc_id
  }

  depends_on = [module.eks]
}
