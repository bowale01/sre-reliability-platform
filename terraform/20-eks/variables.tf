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

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane."
  type        = string
  default     = "1.30"
}

variable "state_bucket" {
  description = "S3 bucket holding the foundation layer's remote state."
  type        = string
}

variable "system_node_instance_types" {
  description = "Instance types for the small stable system node group (runs Karpenter, CoreDNS, controllers)."
  type        = list(string)
  default     = ["t3.large"]
}

variable "system_node_min_size" {
  description = "Minimum nodes in the system node group."
  type        = number
  default     = 2
}

variable "system_node_max_size" {
  description = "Maximum nodes in the system node group."
  type        = number
  default     = 3
}

variable "system_node_desired_size" {
  description = "Desired nodes in the system node group."
  type        = number
  default     = 2
}
