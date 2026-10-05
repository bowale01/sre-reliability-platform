output "availability_slo_id" {
  description = "ID of the availability SLO."
  value       = datadog_service_level_objective.availability.id
}

output "latency_slo_id" {
  description = "ID of the latency SLO."
  value       = datadog_service_level_objective.latency.id
}

output "dashboard_url" {
  description = "URL of the SLO dashboard."
  value       = "https://app.${var.datadog_site}/dashboard/${datadog_dashboard.slo.id}"
}

output "monitor_ids" {
  description = "IDs of the burn-rate monitors."
  value = {
    availability_fast_burn = datadog_monitor.availability_fast_burn.id
    availability_slow_burn = datadog_monitor.availability_slow_burn.id
    latency_fast_burn      = datadog_monitor.latency_fast_burn.id
    latency_slow_burn      = datadog_monitor.latency_slow_burn.id
  }
}
