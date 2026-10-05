# ---------------------------------------------------------------------------
# GitOps delivery: ArgoCD + Argo Rollouts.
#
#   - ArgoCD continuously reconciles the cluster to match the Helm chart in Git
#     (charts/demo-service), so Git is the single source of truth.
#   - Argo Rollouts executes the SLO-gated canary defined by the chart's Rollout.
#   - A Datadog metrics secret lets the Rollouts controller run the
#     AnalysisTemplate queries that gate the canary.
#
# CI only builds the image and bumps image.tag in values.yaml (a Git commit).
# ArgoCD does the deploy. There is no `kubectl apply` of app manifests.
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
    key = "50-argocd/terraform.tfstate"
    # bucket         = "<from 00-remote-state output>"
    # dynamodb_table = "<from 00-remote-state output>"
    # region         = "us-east-1"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
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
# Argo Rollouts controller (progressive delivery engine).
# --------------------------------------------------------------------------- #
resource "helm_release" "argo_rollouts" {
  name             = "argo-rollouts"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-rollouts"
  version          = var.argo_rollouts_chart_version
  namespace        = "argo-rollouts"
  create_namespace = true

  # Install the kubectl plugin dashboard too (handy for demos).
  set {
    name  = "dashboard.enabled"
    value = "true"
  }
}

# Datadog metrics provider secret the Rollouts controller uses for analysis.
resource "kubernetes_secret" "rollouts_datadog" {
  metadata {
    name      = "datadog"
    namespace = "argo-rollouts"
  }
  data = {
    # Keys expected by the Rollouts Datadog metrics provider.
    "api-key" = var.datadog_api_key
    "app-key" = var.datadog_app_key
    "address" = "https://api.${var.datadog_site}"
  }
  type = "Opaque"

  depends_on = [helm_release.argo_rollouts]
}

# --------------------------------------------------------------------------- #
# ArgoCD (GitOps control plane).
# --------------------------------------------------------------------------- #
resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = "argocd"
  create_namespace = true

  values = [yamlencode({
    # Run ArgoCD on the system node group (tolerate the taint).
    global = {
      tolerations = [{
        key      = "CriticalAddonsOnly"
        operator = "Exists"
      }]
    }
    configs = {
      params = {
        # ALB terminates TLS; let the ArgoCD server run insecure behind it.
        "server.insecure" = true
      }
    }
  })]
}

# --------------------------------------------------------------------------- #
# App-of-apps: a single root Application that points at the Git repo path for
# the service chart. ArgoCD reconciles it (and could manage more apps the same
# way as the platform grows).
# --------------------------------------------------------------------------- #
resource "kubernetes_manifest" "root_app" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "demo-service"
      namespace = "argocd"
      finalizers = ["resources-finalizer.argocd.argoproj.io"]
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.git_repo_url
        targetRevision = var.git_target_revision
        path           = "charts/demo-service"
        helm = {
          valueFiles = ["values.yaml"]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = var.app_namespace
      }
      syncPolicy = {
        automated = {
          prune    = true
          selfHeal = true # auto-correct drift
        }
        syncOptions = ["CreateNamespace=true"]
      }
    }
  }

  depends_on = [helm_release.argocd]
}
