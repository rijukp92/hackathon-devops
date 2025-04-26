variable "environment" {
  description = "Environment of the stack"
  type        = string
}

variable "region" {
  description = "AWS region to deploy"
  type        = string
}

variable "oidc_provider" {
    description = "OIDC provider of EKS" 
    type = string
}

variable "name" {
  description = "EKS cluster name"
  type        = string
}

variable "ebs-csi-addon_version" {
  description = "Version of EBS CSI driver addon"
  type        = string
}