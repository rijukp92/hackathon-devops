variable "aws_region" {}
variable "environment" {}
variable "vpc_cidr" {}
variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}
variable "eks_cluster_name" {}
variable "node_instance_type" {}
variable "desired_capacity" {}
variable "min_size" {}
variable "max_size" {}
