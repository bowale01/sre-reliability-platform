output "cluster_name" {
  description = "EKS cluster name."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_oidc_provider_arn" {
  description = "OIDC provider ARN for IRSA (used by later layers)."
  value       = module.eks.oidc_provider_arn
}

output "update_kubeconfig_command" {
  description = "Run this to point kubectl at the new cluster."
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}

output "cluster_certificate_authority_data" {
  description = "Base64 CA data for the cluster (used by later layers' k8s providers)."
  value       = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  description = "Security group ID shared by the cluster's nodes (tagged for Karpenter discovery)."
  value       = module.eks.node_security_group_id
}

output "eks_managed_node_group_iam_role_name" {
  description = "IAM role name of the system managed node group (reused for Karpenter node identity)."
  value       = module.eks.eks_managed_node_groups["system"].iam_role_name
}

output "oidc_provider" {
  description = "OIDC provider URL (without https://) for IRSA trust policies."
  value       = module.eks.oidc_provider
}
