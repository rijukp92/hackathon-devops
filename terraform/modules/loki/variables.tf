variable "region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment of the stack"
  type        = string
}

variable "bucket_name" {
  description = "Bucket name for Loki storage"
  type        = string
}

variable "cluster_name" {
  description = "Name of EKS cluster"
  type        = string
}

variable "namespace" {
  description = "Namespace of Loki installation"
  type        = string
  default     = "loki"
}

variable "serviceaccount" {
  description = "Service account of Loki installation"
  type        = string
  default     = "loki-service-account"
}

variable "oidc_provider" {
  description = "oidc provider of eks cluster"
  type        = string
}