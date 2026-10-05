output "datadog_namespace" {
  description = "Namespace where the Datadog Agent is installed."
  value       = kubernetes_namespace.datadog.metadata[0].name
}

output "datadog_helm_release" {
  description = "Name of the Datadog Helm release."
  value       = helm_release.datadog.name
}
