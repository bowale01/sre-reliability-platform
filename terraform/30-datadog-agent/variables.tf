variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name to install the Datadog Agent on."
  type        = string
  default     = "sre-demo"
}

variable "datadog_api_key" {
  description = "Datadog API key."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key."
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, us5.datadoghq.com)."
  type        = string
  default     = "datadoghq.com"
}

variable "datadog_chart_version" {
  description = "Version of the Datadog Helm chart."
  type        = string
  default     = "3.72.1"
}
