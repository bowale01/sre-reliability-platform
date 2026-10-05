variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name prefix used for resource naming and tagging."
  type        = string
  default     = "sre-demo"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "sre-demo"
}

variable "state_bucket" {
  description = "S3 bucket holding the 20-eks layer's remote state."
  type        = string
}

variable "karpenter_version" {
  description = "Version of the Karpenter Helm chart."
  type        = string
  default     = "1.0.6"
}
