variable "datadog_api_key" {
  description = "Datadog API key."
  type        = string
  sensitive   = true
}

variable "datadog_app_key" {
  description = "Datadog Application key."
  type        = string
  sensitive   = true
}

variable "datadog_site" {
  description = "Datadog site (e.g. datadoghq.com, datadoghq.eu, us5.datadoghq.com)."
  type        = string
  default     = "datadoghq.com"
}

variable "service_name" {
  description = "Service name used in SLI metric filters and tags."
  type        = string
  default     = "demo-service"
}

variable "env" {
  description = "Environment tag used in SLI metric filters."
  type        = string
  default     = "prod"
}

variable "availability_slo_target" {
  description = "Availability SLO target as a percentage (e.g. 99.9)."
  type        = number
  default     = 99.9
}

variable "latency_slo_target" {
  description = "Latency SLO target as a percentage (e.g. 99.0)."
  type        = number
  default     = 99.0
}

variable "latency_threshold_seconds" {
  description = "Latency threshold for the 'good' bucket in seconds (e.g. 0.3 = 300ms)."
  type        = number
  default     = 0.3
}

variable "alert_notification" {
  description = "Notification handle appended to monitor messages (e.g. @slack-sre or @pagerduty-sre)."
  type        = string
  default     = "@slack-sre-alerts"
}
