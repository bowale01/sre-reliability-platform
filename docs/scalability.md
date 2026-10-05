# Scalability — proving the autoscaling loop

This project scales on two independent axes, and the k6 load test exercises both
end to end.

## The two-axis model

| Axis | Component | Trigger | Reaction time |
|---|---|---|---|
| **Pods** | HorizontalPodAutoscaler | CPU > 60% average | ~15–30s to decide |
| **Nodes** | Karpenter | pods that can't schedule | ~1 min to a new node |

HPA scales the *number of pods*. When those pods can't fit on existing nodes,
Karpenter provisions *new nodes* just-in-time, choosing the cheapest instance
that fits the pending pods (Spot preferred). When load drops, the HPA scales
pods back down and Karpenter consolidates — repacking the survivors and
terminating now-empty nodes.

## Why Karpenter over Cluster Autoscaler

- **Provisioning speed** — Karpenter calls the EC2 Fleet API directly instead of
  nudging an Auto Scaling Group, so capacity appears in about a minute. During a
  spike, that speed is what keeps the latency SLO intact.
- **Bin-packing** — it picks from a broad instance set based on the actual pod
  requests, instead of being limited to pre-declared node-group shapes. Tighter
  packing = lower cost.
- **Consolidation** — continuous repacking removes waste automatically.
- **Spot-native** — first-class Spot support with graceful interruption handling
  via the SQS queue, ideal for cost-sensitive, elastic workloads.

Tradeoff: more setup (controller IAM/IRSA, node role, SQS + EventBridge) and less
determinism than fixed node groups. Consolidation also needs tuning against PDBs
so it doesn't churn pods. Those are the costs we accepted for speed and efficiency.

## Running the load test

Option A — from your machine against the public ALB:
```bash
ALB=$(kubectl -n demo get ingress demo-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
BASE_URL="http://$ALB" k6 run loadtest/load.js
```

Option B — in-cluster as a Job:
```bash
kubectl -n demo create configmap k6-script --from-file=load.js=loadtest/load.js
kubectl apply -f loadtest/k6-job.yaml
kubectl -n demo logs -f job/k6-loadtest
```

## What to watch while it runs

```bash
# Pods scaling (HPA)
kubectl -n demo get hpa -w
kubectl -n demo get pods -w

# Nodes appearing / consolidating (Karpenter)
kubectl get nodes -L karpenter.sh/capacity-type,node.kubernetes.io/instance-type -w
kubectl -n karpenter logs -l app.kubernetes.io/name=karpenter -f
```

In Datadog, open the **demo-service — SRE / SLO Overview** dashboard and confirm:
- the Rate panel climbs with the load stages,
- p95/p99 latency stays under the 300ms line (latency SLO holds),
- the 5xx panel stays flat (availability SLO holds),
- the error budget barely moves.

## Expected timeline

1. **0–3 min (ramp to 50 VUs):** CPU rises, HPA adds pods, some go Pending,
   Karpenter launches 1–2 nodes.
2. **3–8 min (peak at 200 VUs):** pod count approaches `maxReplicas`, Karpenter
   has added enough nodes; SLIs stay within target.
3. **8–11 min (ramp down):** HPA scales pods in (slow scale-down window avoids
   flapping).
4. **11–15 min (idle):** pods back to `minReplicas`; Karpenter consolidates and
   terminates empty nodes, returning the cluster to its 2-node system baseline.

Capturing before/after dashboard screenshots here makes the scalability story
concrete.
