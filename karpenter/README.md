# Karpenter NodePools

Applied after `terraform/25-karpenter` installs the Karpenter controller.

## Two-tier node model

| Tier | Where it runs | Managed by | Workloads |
|---|---|---|---|
| **system** | EKS managed node group (2 nodes, on-demand, tainted `CriticalAddonsOnly`) | `terraform/20-eks` | Karpenter, CoreDNS, Datadog cluster agent, ALB controller, ArgoCD |
| **app** | Karpenter-provisioned nodes (Spot + on-demand, just-in-time) | this `NodePool` | demo-service and other application pods |

This separation keeps the control plane for autoscaling (Karpenter itself) on
stable capacity, while all elastic application capacity is provisioned on demand
and consolidated away when idle.

## Apply

1. Get the node IAM role name from the Karpenter layer:
   ```bash
   cd terraform/25-karpenter && terraform output -raw karpenter_node_iam_role_name
   ```
2. Substitute it into the EC2NodeClass and apply both manifests:
   ```bash
   sed "s/REPLACE_WITH_KARPENTER_NODE_ROLE/<role-name>/" karpenter/ec2nodeclass.yaml | kubectl apply -f -
   kubectl apply -f karpenter/nodepool-app.yaml
   ```
   (If your cluster name is not `sre-demo`, also update the `discovery` tag values.)

## How it proves the scalability story

- Application pods request CPU/memory but **cannot** schedule on the tainted
  system group, so they go Pending.
- Karpenter sees the Pending pods and launches the cheapest instance that fits
  them (Spot preferred), typically within a minute.
- When the HPA scales the service up under load, Karpenter adds nodes to match.
- When load drops and pods scale back down, `consolidationPolicy:
  WhenEmptyOrUnderutilized` repacks remaining pods and terminates the now-empty
  nodes, returning the cluster to its small baseline.

See `docs/deployment-safety.md` and the k6 load test in `loadtest/` for the
end-to-end demonstration.
