output "argocd_namespace" {
  description = "Namespace where ArgoCD is installed."
  value       = helm_release.argocd.namespace
}

output "argocd_initial_admin_password_hint" {
  description = "How to retrieve the initial ArgoCD admin password."
  value       = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "argocd_port_forward_hint" {
  description = "How to reach the ArgoCD UI locally."
  value       = "kubectl -n argocd port-forward svc/argocd-server 8080:80  # then open http://localhost:8080"
}

output "rollouts_dashboard_hint" {
  description = "How to open the Argo Rollouts dashboard."
  value       = "kubectl argo rollouts dashboard  # requires the kubectl-argo-rollouts plugin"
}
