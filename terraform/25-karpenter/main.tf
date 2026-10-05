# ---------------------------------------------------------------------------
# Karpenter: just-in-time node autoscaling for EKS.
#
# Why Karpenter over Cluster Autoscaler:
#   - Groupless, pod-driven provisioning: launches the OPTIMAL instance for the
#     exact pending pods (bin-packing) instead of scaling fixed ASGs.
#   - Faster: talks to the EC2 Fleet API directly, so nodes appear in seconds-
#     to-a-minute, which protects the latency SLO during traffic spikes.
#   - Consolidation: continuously repacks workloads and removes underused nodes.
#   - Spot-native with graceful interruption handling (via the SQS queue below).
#
# This layer provisions the IAM/SQS/EventBridge plumbing and installs the
# Karpenter controller. The NodePool + EC2NodeClass (what Karpenter actually
# provisions) are applied separately from karpenter/ manifests.
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
    key = "25-karpenter/terraform.tfstate"
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
      Layer     = "25-karpenter"
    }
  }
}

# Read EKS details from the 20-eks layer.
data "terraform_remote_state" "eks" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "20-eks/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.cluster_name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# --------------------------------------------------------------------------- #
# Karpenter IAM + SQS interruption queue + EventBridge rules.
# The official submodule wires all of this together, including the node IAM
# role and the EKS access entry that lets Karpenter-launched nodes join.
# --------------------------------------------------------------------------- #
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "~> 20.24"

  cluster_name = var.cluster_name

  # Use IRSA (OIDC) for the controller identity.
  enable_irsa                     = true
  irsa_oidc_provider_arn          = data.terraform_remote_state.eks.outputs.cluster_oidc_provider_arn
  irsa_namespace_service_accounts = ["karpenter:karpenter"]

  # Create the node IAM role and attach the standard worker policies so
  # Karpenter-launched nodes can join the cluster and pull images.
  create_node_iam_role = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  # Create the SQS queue + EventBridge rules for spot interruption / health
  # events so Karpenter can gracefully drain nodes before they're reclaimed.
  enable_spot_termination = true

  tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }
}

# --------------------------------------------------------------------------- #
# Karpenter controller (Helm). Installed into the "karpenter" namespace and
# pinned to the system node group via the CriticalAddonsOnly toleration.
# --------------------------------------------------------------------------- #
resource "helm_release" "karpenter" {
  namespace        = "karpenter"
  create_namespace = true

  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  chart               = "karpenter"
  version             = var.karpenter_version
  wait                = true

  values = [yamlencode({
    settings = {
      clusterName       = var.cluster_name
      clusterEndpoint   = data.aws_eks_cluster.this.endpoint
      interruptionQueue = module.karpenter.queue_name
    }

    serviceAccount = {
      name = "karpenter"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.karpenter.iam_role_arn
      }
    }

    # Run the controller on the tainted system node group.
    tolerations = [{
      key      = "CriticalAddonsOnly"
      operator = "Exists"
    }]

    # HA controller.
    replicas = 2

    controller = {
      resources = {
        requests = { cpu = "500m", memory = "512Mi" }
        limits   = { cpu = "1", memory = "1Gi" }
      }
    }
  })]

  depends_on = [module.karpenter]
}
