# Deployment Safety — zero-downtime, canary, and rollback

How this project ships changes without burning the error budget.

The primary path is an **SLO-gated canary** via Argo Rollouts (§4). The chart can also
render a plain `Deployment` (set `rollout.enabled: false`), which uses the conservative
rolling strategy below — useful as a fallback or in environments without Argo Rollouts.

## 1. Zero-downtime rolling updates (Deployment fallback)

When rendered as a `Deployment`, the service uses a conservative `RollingUpdate` strategy:

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 0   # never drop below desired capacity
    maxSurge: 1         # add one new pod at a time
```

- `maxUnavailable: 0` guarantees we never remove an old pod until a new one is **Ready**.
- Readiness is gated by the `/readyz` probe, so traffic only shifts to a pod that
  reports it can serve.
- A `PodDisruptionBudget` (`minAvailable: 2`) protects the service during voluntary
  disruptions like node drains and cluster upgrades.

Combined, a bad image that never becomes Ready simply stalls the rollout — it does not
take down the running version.

## 2. Health model

| Probe | Endpoint | Purpose | Failure action |
|---|---|---|---|
| startup | `/healthz` | tolerate slow starts | keep waiting up to ~60s |
| liveness | `/healthz` | detect a wedged process | restart the container |
| readiness | `/readyz` | gate traffic + rollout | remove from Service endpoints |

Keeping liveness and readiness separate avoids the classic trap where a dependency
blip triggers a restart storm. A not-ready pod is pulled from rotation; only a truly
dead process is restarted.

## 3. CI/CD rollout with automatic rollback

Delivery is **GitOps**, split cleanly between CI and CD:

**CI** (`.github/workflows/deploy.yaml`) — builds and releases, but does **not** deploy:
1. Build the image, tag it with the Git SHA (immutable — no mutable `:latest` in prod).
2. Push to ECR.
3. Bump `image.tag` (and the version tag) in `charts/demo-service/values.yaml` with
   `yq` and commit it back to `main`. That commit is the release.

**CD** (ArgoCD, in-cluster) — reconciles the cluster to match Git:
4. ArgoCD detects the `values.yaml` change and syncs the chart. `selfHeal: true` means
   any manual drift is corrected back to what Git says.
5. Because the workload is an Argo Rollouts `Rollout`, the sync triggers a **canary**,
   not an all-at-once replace (see §4).

Git is the single source of truth: what's deployed is exactly what's committed, and
rollback is a `git revert` of the release commit.

## 4. SLO-gated canary (implemented)

The service is an Argo Rollouts `Rollout` with a canary strategy
(`charts/demo-service/templates/rollout.yaml`). Instead of shifting 100% of traffic at
once, the new version is promoted in steps and judged against its own SLIs:

1. Traffic steps: **5% → 25% → 50% → 100%**, with a pause between each. The AWS Load
   Balancer Controller splits ALB traffic by weight between a **stable** and a
   **canary** Service.
2. Once the canary starts taking traffic, Argo Rollouts runs the Datadog
   `AnalysisTemplate` (`templates/analysistemplate.yaml`) on a loop. The queries are
   scoped to `version:canary` via unified service tagging, so only the new pods are
   judged:
   - **availability** — canary 5xx ratio must stay **< 1%**
   - **latency** — **≥ 99%** of canary requests must be under **300ms**
3. If either metric fails its success condition beyond the `failureLimit`, the
   AnalysisRun fails and the Rollout **automatically aborts and rolls back** to stable.

This closes the loop: the same SLIs that define the SLO also gate the deploy, so a
regression is caught at 5% of traffic instead of 100%. Watch it with:

```bash
kubectl argo rollouts get rollout demo-service -n demo --watch
```

## 5. Node-level safety during scaling

Because Karpenter continuously consolidates nodes, pods can be rescheduled as the
cluster right-sizes. Two guardrails keep that safe:
- the **PDB** (`minAvailable: 2`) blocks consolidation from evicting too many pods at once;
- `terminationGracePeriod` + readiness gating ensure a replacement is Ready before the
  old pod goes away.

## 6. Guardrails summary

- Immutable, SHA-tagged images (no mutable `:latest`).
- GitOps: Git is the source of truth; drift is auto-healed; rollback is `git revert`.
- `maxUnavailable: 0` + readiness gating = no capacity dip (plain-rollout fallback).
- SLO-gated canary auto-aborts on availability/latency breach.
- PDB protects against voluntary disruption, including Karpenter consolidation.
