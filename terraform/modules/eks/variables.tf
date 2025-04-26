variable "environment" {
  description = "Environment of the stack"
  type        = string
}

variable "region" {
  description = "AWS region to deploy"
  type        = string
}

variable "name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_version" {
  description = "EKS cluster version"
  type        = string
}

variable "private_subnets" {
  description = "CIDR range for the private subnets"
  type        = list(string)
}

variable "app_group_instance_type" {
  description = "Instance type for worker group"
  type        = string
}

variable "app_min_size" {
  description = "Minimum size of EC2 instances for app worker group"
  type        = string
}

variable "app_max_size" {
  description = "Maximum size of EC2 instances for app worker group"
  type        = string
}

variable "app_desired_size" {
  description = "Desired size of EC2 instances for app worker group"
  type        = string
}

variable "vpc_id" {
  description = "vpc id"
  type        = string
}

variable "pre_bootstrap_user_data" {
  description = "User data that is injected into the user data script ahead of the EKS bootstrap script. Not used when `platform` = `bottlerocket`"
  type        = string
  default     = ""
}

variable "post_bootstrap_user_data" {
  description = "User data that is appended to the user data script after of the EKS bootstrap script. Not used when `platform` = `bottlerocket`"
  type        = string
  default     = ""
}

variable "additional_security_group_ids" {
  description = "Additional security "
  type        = string
}
