variable "region" {
  description = "Region of the stack"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment of the stack"
  type        = string
  default     = "dev"
}

variable "name" {
  description = "Name of the VPC where EKS cluster is to be deployed"
  type        = string
  default     = "hackathon-devops-riju"
}

variable "vpc_cidr" {
  description = "CIDR range for the VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "private_subnets" {
  description = "CIDR range for the private subnets"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "public_subnets" {
  description = "CIDR range for the public subnets"
  type        = list(string)
  default     = ["10.1.11.0/24", "10.1.12.0/24", "10.1.13.0/24"]
}

variable "db_subnets" {
  description = "CIDR range for the db subnets"
  type        = list(string)
  default     = ["10.1.21.0/24", "10.1.22.0/24", "10.1.23.0/24"]
}


### EKS variables

variable "cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.31"
}

variable "app_group_instance_type" {
  description = "Instance type of app worker group instances"
  type        = string
  default     = "t2.medium"
}

variable "app_min_size" {
  description = "min number of instances for app workers group"
  type        = string
  default     = "4"
}
variable "app_max_size" {
  description = "max number of instances for app workers group"
  type        = string
  default     = "20"
}
variable "app_desired_size" {
  description = "desired number of instances for app workers group"
  type        = string
  default     = "4"
}

