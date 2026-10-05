# Runbook — demo-service

Operational guide for responding to alerts on `demo-service`. Keep actions here
copy-pasteable. Assumes `kubectl` is pointed at the cluster and namespace is `demo`.

## Quick reference

```bash
NS=demo
DEP=demo-service

kubectl get pods -n $NS -o wide
kubectl get deploy,hpa,pdb -n $NS
kubectl rollout status deployment/$DEP -n $NS
kubectl logs -n $NS -l app.kubernetes.io/name=$DEP --tail=100 -f
kubectl describe deploy/$DEP -n $NS
```

Dashboards: **demo-service — SRE / SLO Overview** (link in `terraform/40-observability`
output `dashboard_url`).

---

## Alert: Availability FAST burn (page)

**Meaning:** 5xx responses are consuming the availability error budget quickly.

Triage:
1. Open the SLO dashboard. Confirm the 5xx rate panel is elevated and check which
   `status_code` and `tenant` dominate.
2. Check recent deploys — this is the most common cause.
   ```bash
   kubectl rollout history deployment/$DEP -n $NS
   ```
   If a deploy lines up with the spike, roll back:
   ```bash
   kubectl rollout undo deployment/$DEP -n $NS
   kubectl rollout status deployment/$DEP -n $NS
   ```
3. Check pod health and restarts:
   ```bash
   kubectl get pods -n $NS
   kubectl describe pod -n $NS <crashing-pod>
   ```
4. Check dependency health (the demo service returns 503 on injected upstream faults —
   in a real service, inspect the upstream here).
5. If capacity-related, confirm the HPA scaled and nodes have room:
   ```bash
   kubectl get hpa -n $NS
   kubectl top pods -n $NS
   kubectl top nodes
   ```

Mitigations, in order of preference: roll back the bad release → scale out → shed load
/ enable a degraded mode → fail over.

---

## Alert: Latency FAST burn (page)

**Meaning:** too many requests are slower than the 300ms threshold.

Triage:
1. On the dashboard, compare p95/p99 against the rate panel. Latency rising with traffic
   points to saturation; latency rising without traffic points to a dependency or a
   code regression.
2. Check CPU saturation and whether the HPA is keeping up:
   ```bash
   kubectl top pods -n $NS
   kubectl get hpa -n $NS
   ```
   If pods are pinned at the CPU limit and HPA is at `maxReplicas`, raise `maxReplicas`
   or the CPU limit.
3. Check for a recent deploy (same as availability) and roll back if correlated.
4. Look for slow dependencies in APM traces (Datadog APM, service `demo-service`).

---

## Alert: SLOW burn (ticket)

**Meaning:** a gradual regression. Not an emergency, but it will threaten the SLO if
ignored.

Actions:
1. Create a ticket; attach the dashboard time range showing the trend.
2. Bisect recent changes (deploys, config, dependency versions) over the burn window.
3. Fix within the error-budget policy timeframe before the budget is exhausted.

---

## Common operations

**Scale manually (temporary):**
```bash
kubectl scale deployment/$DEP -n $NS --replicas=6
```

**Drain a node safely (PDB keeps a quorum up):**
```bash
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
```

**Confirm the Datadog Agent is scraping metrics:**
```bash
kubectl get pods -n datadog
kubectl exec -n datadog <datadog-agent-pod> -- agent status | grep -A5 openmetrics
```

**Verify readiness directly:**
```bash
kubectl run smoke --rm -i --restart=Never -n $NS \
  --image=curlimages/curl:8.9.1 -- \
  curl -fsS http://$DEP.$NS.svc.cluster.local/readyz
```
