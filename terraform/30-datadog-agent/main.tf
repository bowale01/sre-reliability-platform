# ---------------------------------------------------------------------------
# Datadog Agent on EKS (Helm) + Datadog provider setup.
#
# Installs the Datadog Agent as a DaemonSet with:
#   - metrics collection (incl. Autodiscovery / OpenMetrics scraping)
#   - APM/traces (ddtrace from the service reports to the local agent)
#   - log collection from all containers
#   - the cluster agent (cluster-level checks, metadata, DCA)
#
# The service's pod annotations (k8s/deployment.yaml) tell the agent to scrape
# the /metrics endpoint via Autodiscovery.
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
    key = "30-datadog-agent/terraform.tfstate"
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

# Store the Datadog keys in a Kubernetes secret the Helm chart references.
resource "kubernetes_namespace" "datadog" {
  metadata {
    name = "datadog"
  }
}

resource "kubernetes_secret" "datadog_keys" {
  metadata {
    name      = "datadog-keys"
    namespace = kubernetes_namespace.datadog.metadata[0].name
  }
  data = {
    "api-key" = var.datadog_api_key
    "app-key" = var.datadog_app_key
  }
  type = "Opaque"
}

resource "helm_release" "datadog" {
  name       = "datadog"
  repository = "https://helm.datadoghq.com"
  chart      = "datadog"
  namespace  = kubernetes_namespace.datadog.metadata[0].name
  version    = var.datadog_chart_version

  values = [yamlencode({
    datadog = {
      site        = var.datadog_site
      clusterName = var.cluster_name

      apiKeyExistingSecret = kubernetes_secret.datadog_keys.metadata[0].name
      appKeyExistingSecret = kubernetes_secret.datadog_keys.metadata[0].name

      # Unified service tagging across the environment.
      tags = ["env:prod"]

      # APM / traces (service reports via ddtrace to the node agent).
      apm = {
        portEnabled           = true
        socketEnabled         = true
        instrumentation       = { enabled = false }
      }

      # Log collection from all containers.
      logs = {
        enabled             = true
        containerCollectAll = true
      }

      # Live process + container metrics.
      processAgent = {
        enabled           = true
        processCollection = true
      }

      # DogStatsD for custom metrics from workloads.
      dogstatsd = {
        useHostPort          = true
        nonLocalTraffic      = true
      }

      # Pick up Autodiscovery annotations (OpenMetrics scraping of /metrics).
      prometheusScrape = {
        enabled                  = true
        enableServiceEndpoints   = true
      }
    }

    # Cluster Agent: cluster-level checks, metadata, and the external metrics API.
    clusterAgent = {
      enabled  = true
      replicas = 2
      metricsProvider = {
        enabled = true
      }
    }

    # Node agent runs as a DaemonSet by default.
    agents = {
      enabled = true
    }
  })]

  depends_on = [kubernetes_secret.datadog_keys]
}
