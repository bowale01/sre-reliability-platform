variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "sre-demo"
}

variable "git_repo_url" {
  description = "Git repository URL ArgoCD watches (where this repo lives)."
  type        = string
}

variable "git_target_revision" {
  description = "Git branch/tag/commit ArgoCD tracks."
  type        = string
  default     = "main"
}

variable "app_namespace" {
  description = "Namespace the demo service is deployed into."
  type        = string
  default     = "demo"
}

variable "datadog_api_key" {
  description = "Datadog API key (for the Rollouts analysis provider)."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key (for the Rollouts analysis provider)."
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site."
  type        = string
  default     = "datadoghq.com"
}

variable "argocd_chart_version" {
  description = "Version of the argo-cd Helm chart."
  type        = string
  default     = "7.6.12"
}

variable "argo_rollouts_chart_version" {
  description = "Version of the argo-rollouts Helm chart."
  type        = string
  default     = "2.37.7"
}
