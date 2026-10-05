# ---------------------------------------------------------------------------
# Error-budget burn-rate alerts (multi-window, multi-burn-rate).
#
# Based on the Google SRE Workbook "Alerting on SLOs" guidance:
#   - FAST burn:  consumes ~2% of the 30d budget in 1h  -> page (urgent)
#   - SLOW burn:  consumes ~10% of the 30d budget in 3d -> ticket (non-urgent)
#
# Datadog's `slo` monitor type with `error_budget` evaluates burn against the
# SLO's error budget directly, so we express thresholds as "% of budget".
# ---------------------------------------------------------------------------

# ---- Availability: fast burn (page) ----
resource "datadog_monitor" "availability_fast_burn" {
  name    = "[SLO burn] ${var.service_name} availability — FAST burn (page)"
  type    = "slo alert"
  message = <<-EOT
    Availability error budget is burning fast. At this rate the 30-day budget
    will be exhausted well before the window ends. Investigate 5xx sources now.

    Runbook: docs/runbook.md
    ${var.alert_notification}
  EOT

  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"1h\").long_window(\"5m\") > 14.4"

  monitor_thresholds {
    critical = 14.4 # ~2% of a 30d budget in 1h
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "severity:page"]
}

# ---- Availability: slow burn (ticket) ----
resource "datadog_monitor" "availability_slow_burn" {
  name    = "[SLO burn] ${var.service_name} availability — SLOW burn (ticket)"
  type    = "slo alert"
  message = <<-EOT
    Availability error budget is burning slowly but steadily. Open a ticket to
    investigate before it threatens the SLO.

    Runbook: docs/runbook.md
    ${var.alert_notification}
  EOT

  query = "burn_rate(\"${datadog_service_level_objective.availability.id}\").over(\"3d\").long_window(\"1h\") > 1"

  monitor_thresholds {
    critical = 1 # ~10% of a 30d budget in 3d
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "severity:ticket"]
}

# ---- Latency: fast burn (page) ----
resource "datadog_monitor" "latency_fast_burn" {
  name    = "[SLO burn] ${var.service_name} latency — FAST burn (page)"
  type    = "slo alert"
  message = <<-EOT
    Latency error budget is burning fast (too many requests slower than
    ${var.latency_threshold_seconds * 1000}ms). Check saturation, dependencies, and recent deploys.

    Runbook: docs/runbook.md
    ${var.alert_notification}
  EOT

  query = "burn_rate(\"${datadog_service_level_objective.latency.id}\").over(\"1h\").long_window(\"5m\") > 14.4"

  monitor_thresholds {
    critical = 14.4
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "severity:page"]
}

# ---- Latency: slow burn (ticket) ----
resource "datadog_monitor" "latency_slow_burn" {
  name    = "[SLO burn] ${var.service_name} latency — SLOW burn (ticket)"
  type    = "slo alert"
  message = <<-EOT
    Latency error budget is burning slowly. Open a ticket to investigate the
    gradual regression before it threatens the SLO.

    Runbook: docs/runbook.md
    ${var.alert_notification}
  EOT

  query = "burn_rate(\"${datadog_service_level_objective.latency.id}\").over(\"3d\").long_window(\"1h\") > 1"

  monitor_thresholds {
    critical = 1
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "severity:ticket"]
}
