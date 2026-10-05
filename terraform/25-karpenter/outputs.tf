output "karpenter_node_iam_role_name" {
  description = "IAM role name assumed by Karpenter-launched nodes (referenced by the EC2NodeClass)."
  value       = module.karpenter.node_iam_role_name
}

output "karpenter_controller_role_arn" {
  description = "IAM role ARN for the Karpenter controller (IRSA)."
  value       = module.karpenter.iam_role_arn
}

output "karpenter_interruption_queue" {
  description = "SQS queue name used for spot-interruption / node-health events."
  value       = module.karpenter.queue_name
}

output "ec2nodeclass_values_hint" {
  description = "Values to substitute into the EC2NodeClass manifest."
  value       = <<-EOT
    nodeRole:         ${module.karpenter.node_iam_role_name}
    discoveryTag:     karpenter.sh/discovery = ${var.cluster_name}
  EOT
}
