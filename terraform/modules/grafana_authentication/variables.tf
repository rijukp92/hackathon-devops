variable "admin_api_key" {
  type        = string
  description = "Admin API key for accessing grafana"
}

variable "grafana_endpoint" {
  type        = string
  description = "Grafana workspace endpoint"
}

variable "prometheus_endpoint" {
  type        = string
  description = "Prometheus workspace endpoint"
}

variable "prometheus_workspace_id" {
  type        = string
  description = "Prometheus workspace ID"
}

variable "cluster_metrics_config" {
  type = string
}

variable "cluster_logs_config" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "loki_username" {
 type = string
}

variable "loki_password" {
 type = string
}

variable "tempo_username" {
 type = string
}

variable "tempo_password" {
 type = string
}

variable "opsgenie_api_key" {
 type = string
}

variable "opsgenie_url" {
 type = string
}

variable "slack_recipient" {
 type = string
}

variable "slack_token" {
 type = string
}