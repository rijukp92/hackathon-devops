variable "environment" {
  description = "Environment of the stack"
  type        = string
}

variable "name" {
  description = "Name of the VPC where EKS cluster is to be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
}

variable "private_subnets" {
  description = "CIDR range for the private subnets"
  type        = list(string)
}

variable "public_subnets" {
  description = "CIDR range for the public subnets"
  type        = list(string)
}

variable "db_subnets" {
  description = "CIDR range for the db subnets"
  type        = list(string)
}

variable "azs" {
  description = "Availibility zone names"
  type        = list(string)
}