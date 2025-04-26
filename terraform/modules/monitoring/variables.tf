variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "prometheus_workspace_name" {
  type = string
}

variable "grafana_workspace_name" {
  type = string
}

variable "oidc_provider" {
  type = string
}

variable "namespace" {
  type    = string
  default = "monitoring"
}

variable "cluster_name" {
  description = "Name of EKS cluster"
  type        = string
}