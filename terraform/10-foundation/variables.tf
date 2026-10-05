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
  description = "EKS cluster name (used for subnet discovery tags)."
  type        = string
  default     = "sre-demo"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}
