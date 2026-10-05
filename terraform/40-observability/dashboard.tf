# ---------------------------------------------------------------------------
# SLO dashboard: availability + latency SLO status, RED signals, and burn.
# ---------------------------------------------------------------------------

resource "datadog_dashboard" "slo" {
  title       = "${var.service_name} — SRE / SLO Overview"
  description = "SLI/SLO status, error budgets, and RED (Rate, Errors, Duration) signals."
  layout_type = "ordered"

  widget {
    slo_definition {
      title    = "Availability SLO (30d)"
      slo_id   = datadog_service_level_objective.availability.id
      time_windows = ["30d", "7d", "previous_week"]
      show_error_budget = true
      view_type = "detail"
      view_mode = "both"
    }
  }

  widget {
    slo_definition {
      title    = "Latency SLO (30d)"
      slo_id   = datadog_service_level_objective.latency.id
      time_windows = ["30d", "7d", "previous_week"]
      show_error_budget = true
      view_type = "detail"
      view_mode = "both"
    }
  }

  # Rate: requests per second.
  widget {
    timeseries_definition {
      title = "Rate — requests/sec"
      request {
        q            = "sum:demo_service.http_requests_total.count{service:${var.service_name},env:${var.env}}.as_rate()"
        display_type = "line"
      }
    }
  }

  # Errors: 5xx rate.
  widget {
    timeseries_definition {
      title = "Errors — 5xx/sec"
      request {
        q            = "sum:demo_service.http_requests_total.count{service:${var.service_name},env:${var.env},status_code:5*}.as_rate()"
        display_type = "bars"
        style {
          palette = "warm"
        }
      }
    }
  }

  # Duration: p50/p95/p99 derived from the histogram.
  widget {
    timeseries_definition {
      title = "Duration — latency percentiles (s)"
      request {
        q            = "p50:demo_service.http_request_duration_seconds{service:${var.service_name},env:${var.env}}"
        display_type = "line"
      }
      request {
        q            = "p95:demo_service.http_request_duration_seconds{service:${var.service_name},env:${var.env}}"
        display_type = "line"
      }
      request {
        q            = "p99:demo_service.http_request_duration_seconds{service:${var.service_name},env:${var.env}}"
        display_type = "line"
      }
    }
  }

  # Per-tenant traffic split (multi-tenant visibility).
  widget {
    timeseries_definition {
      title = "Traffic by tenant"
      request {
        q            = "sum:demo_service.http_requests_total.count{service:${var.service_name},env:${var.env}} by {tenant}.as_rate()"
        display_type = "area"
      }
    }
  }
}
