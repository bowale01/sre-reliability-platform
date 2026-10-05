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
