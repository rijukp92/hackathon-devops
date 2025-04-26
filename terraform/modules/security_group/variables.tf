
variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
}

variable "environment" {
  description = "Environment of the stack"
  type        = string
}

variable "vpc_id" {
  description = "VPC Id"
  type        = string
}

variable "name" {
  description = "name prefix for worker group"
  type        = string
}