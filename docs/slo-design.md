# SLO Design — methodology and rationale

This document explains how the SLIs, SLOs, and error budgets in this project are
defined and why. It follows the Google SRE book / SRE workbook model.

## 1. Terminology

- **SLI (Service Level Indicator)** — a quantitative measure of a service aspect,
  expressed as `good events / valid events`. Always a ratio between 0 and 1.
- **SLO (Service Level Objective)** — a target for an SLI over a window
  (e.g. 99.9% over 30 days).
- **Error budget** — `1 − SLO`. The allowed amount of unreliability. A 99.9%
  availability SLO yields a 0.1% error budget: about 43m 50s of "bad" per 30 days.

## 2. Pick SLIs from the user's perspective

We model two critical user journeys for the API and measure what a user actually feels:

| Journey | SLI (good / valid) | Why it matters |
|---|---|---|
| "The API responds successfully" | requests that are **not 5xx** / all requests | Users can't tell a 500 from an outage |
| "The API responds quickly" | requests **faster than 300ms** / all requests | Slow is the new down |

We deliberately exclude 4xx from the "bad" set for availability: a client sending a
bad request is not the service failing. This is a common and important distinction.

## 3. The SLI math (as implemented in Datadog)

Both SLIs are **count-based** metric SLOs: `sum(good) / sum(total)` over the window.

**Availability**
```
good  = sum(http_requests_total) − sum(http_requests_total where status_code = 5xx)
total = sum(http_requests_total)
```

**Latency**
```
good  = sum(http_request_duration_seconds_bucket where le = 0.3)   # requests ≤ 300ms
total = sum(http_request_duration_seconds_count)                   # all requests
```

The latency SLI uses the Prometheus histogram's cumulative buckets. The 300ms
threshold sits exactly on a histogram bucket boundary (see the service's
`REQUEST_LATENCY` buckets) so the "good" count is exact, not interpolated.

See `terraform/40-observability/slos.tf`.

## 4. Targets and windows

| SLO | Target | Window | Error budget |
|---|---|---|---|
| Availability | 99.9% | 30d rolling | ~43m 50s / 30d |
| Latency | 99.0% | 30d rolling | ~7h 18m / 30d |

A **rolling** 30-day window (not calendar) gives continuous feedback and avoids a
budget "reset cliff" at month boundaries. We also attach a 7-day view for a faster
signal on regressions.

Targets start intentionally modest. The right way to raise a target is to earn it:
hold the current SLO for a few windows, confirm headroom, then tighten.

## 5. Error budget policy

The budget is a shared agreement between product and engineering about how to spend
reliability:

- **Budget remaining** → ship features, take measured risks, run experiments.
- **Budget exhausted** → freeze risky changes, redirect effort to reliability work
  (bug fixes, hardening, rollback of the regressing change) until the budget recovers.

This turns "how reliable should we be?" from an argument into a data-driven policy.

## 6. Alerting: burn rate, not raw threshold

Alerting directly on "SLI dropped below target" is noisy and slow. Instead we alert on
**burn rate** — how fast the error budget is being consumed — using multi-window,
multi-burn-rate alerts (SRE workbook, "Alerting on SLOs"):

| Alert | Condition | Budget consumed | Action |
|---|---|---|---|
| Fast burn | burn rate > 14.4 over 1h (confirmed over 5m) | ~2% of 30d budget in 1h | **Page** |
| Slow burn | burn rate > 1 over 3d (confirmed over 1h) | ~10% of 30d budget in 3d | **Ticket** |

Burn rate of 1.0 means "consuming budget exactly as fast as the window allows." 14.4
is the standard fast-burn multiplier (2% of a 30-day budget in 1 hour). The long
window on each alert suppresses flapping; the short window makes it reset quickly once
the issue clears.

See `terraform/40-observability/monitors.tf`.

## 7. What this intentionally leaves out

- Per-tenant SLOs: the data is tagged by `tenant`, so tenant-scoped SLOs are a natural
  next step (clone the SLO with a `tenant:` filter).
- Request-weighted vs. time-weighted SLIs: we use request-weighted (count), which best
  matches user experience for an API.
