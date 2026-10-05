output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs (EKS nodes land here)."
  value       = module.vpc.private_subnets
}

output "public_subnet_ids" {
  description = "Public subnet IDs (ALBs land here)."
  value       = module.vpc.public_subnets
}

output "ecr_repository_url" {
  description = "URL of the ECR repository for the demo service image."
  value       = aws_ecr_repository.service.repository_url
}
