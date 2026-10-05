# Incident Response — process

A lightweight incident command process suited to a multi-tenant SaaS platform. The
goal: restore service fast, communicate clearly, and learn without blame.

## 1. Severity levels

| Sev | Definition | Example | Response |
|---|---|---|---|
| **SEV1** | Full outage or data risk; many tenants | API down, data loss risk | Page immediately, all-hands |
| **SEV2** | Major degradation; SLO at serious risk | Fast-burn page, one region impaired | Page on-call, IC assigned |
| **SEV3** | Minor/partial; limited scope | Slow burn, single tenant degraded | Ticket, handle in business hours |

Burn-rate alerts map directly: **fast burn → SEV2 (or SEV1 if widening)**,
**slow burn → SEV3**.

## 2. Roles

For anything SEV2+:

- **Incident Commander (IC)** — owns the response, makes decisions, keeps the timeline.
  The IC coordinates; they do not have to be the one typing commands.
- **Operations / Responder(s)** — investigate and apply mitigations.
- **Communications Lead** — updates stakeholders and the status page (can be the IC in
  a small incident).
- **Scribe** — timestamps key events, decisions, and findings in the incident channel.

One person can hold multiple roles in a small incident; split them as it grows.

## 3. Lifecycle

1. **Detect** — an alert fires (burn-rate monitor) or a report comes in.
2. **Triage** — assess severity, declare the incident, open a channel, assign IC.
3. **Mitigate first** — restore service before diagnosing root cause. Preferred levers,
   in order: roll back the suspect release → scale out → shed load / degrade gracefully
   → fail over. See `runbook.md` for the exact commands.
4. **Communicate** — post an initial update fast, then on a regular cadence (e.g. every
   30 min for SEV2), even if the update is "still investigating."
5. **Resolve** — confirm SLIs have recovered on the dashboard and the burn-rate alert
   has cleared. Downgrade/close the incident.
6. **Learn** — run a blameless postmortem.

## 4. Mitigation before diagnosis

The single most important principle: **stop the bleeding first**. A clean rollback that
restores users in two minutes beats a 40-minute root-cause hunt while the budget burns.
Diagnosis happens once the service is stable (or in parallel, by a second responder).

## 5. Blameless postmortem

Required for every SEV1 and SEV2. Written within a few business days while memory is
fresh. Structure:

- **Summary** — what happened, impact (duration, tenants, error-budget spent).
- **Timeline** — detection → mitigation → resolution, with timestamps.
- **Root cause** — the technical and contributing systemic causes.
- **What went well / what went poorly.**
- **Action items** — concrete, owned, and tracked. Each one should make a recurrence
  less likely or faster to resolve.

Blameless means we focus on systems and processes, not individuals. People act
reasonably given the information they had; if an action looks wrong in hindsight, the
question is what made it look right at the time.

## 6. Tying it back to error budgets

Every incident spends error budget. The postmortem should quantify how much. A pattern
of budget-threatening incidents is the signal defined in the error-budget policy
(`slo-design.md`) to pause risky feature work and invest in reliability until the budget
recovers.
