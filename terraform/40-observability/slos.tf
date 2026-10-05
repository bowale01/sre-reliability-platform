# ---------------------------------------------------------------------------
# Service Level Objectives (metric-based, count style: good / total).
#
# The service exposes Prometheus metrics scraped by the Datadog Agent under the
# OpenMetrics namespace "demo_service" (see k8s/deployment.yaml annotations):
#
#   demo_service.http_requests_total          (counter; tags: status_code, path, tenant, service)
#   demo_service.http_request_duration_seconds (histogram -> .bucket / .count / .sum)
#
# Datadog appends ".count" to Prometheus counters, so the ingested metric is
# `demo_service.http_requests_total.count`.
# ---------------------------------------------------------------------------

locals {
  base_filter = "service:${var.service_name},env:${var.env}"
}

# --------------------------------------------------------------------------- #
# Availability SLO: fraction of requests that are NOT 5xx.
#   good  = all requests minus 5xx
#   total = all requests
# --------------------------------------------------------------------------- #
resource "datadog_service_level_objective" "availability" {
  name        = "${var.service_name} — API availability"
  type        = "metric"
  description = "Proportion of API requests that did not return a 5xx response."

  query {
    numerator   = "sum:demo_service.http_requests_total.count{${local.base_filter}} - sum:demo_service.http_requests_total.count{${local.base_filter},status_code:5*}.as_count()"
    denominator = "sum:demo_service.http_requests_total.count{${local.base_filter}}.as_count()"
  }

  # Rolling 30-day target plus a 7-day view for faster feedback.
  thresholds {
    timeframe = "30d"
    target    = var.availability_slo_target
    warning   = var.availability_slo_target + 0.05
  }
  thresholds {
    timeframe = "7d"
    target    = var.availability_slo_target
    warning   = var.availability_slo_target + 0.05
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "sli:availability"]
}

# --------------------------------------------------------------------------- #
# Latency SLO: fraction of requests served faster than the threshold.
#   good  = requests in histogram buckets <= threshold (le:"0.3")
#   total = all requests (histogram .count)
# --------------------------------------------------------------------------- #
resource "datadog_service_level_objective" "latency" {
  name        = "${var.service_name} — API latency"
  type        = "metric"
  description = "Proportion of API requests served faster than ${var.latency_threshold_seconds * 1000}ms."

  query {
    numerator   = "sum:demo_service.http_request_duration_seconds.bucket{${local.base_filter},upper_bound:${format("%.1f", var.latency_threshold_seconds)}}.as_count()"
    denominator = "sum:demo_service.http_request_duration_seconds.count{${local.base_filter}}.as_count()"
  }

  thresholds {
    timeframe = "30d"
    target    = var.latency_slo_target
    warning   = var.latency_slo_target + 0.5
  }
  thresholds {
    timeframe = "7d"
    target    = var.latency_slo_target
    warning   = var.latency_slo_target + 0.5
  }

  tags = ["service:${var.service_name}", "env:${var.env}", "team:sre", "sli:latency"]
}
