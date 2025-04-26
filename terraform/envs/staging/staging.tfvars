aws_region = "us-east-1"

environment = "staging"

vpc_cidr = "10.1.0.0/16"

public_subnets = [
  "10.1.1.0/24",
  "10.1.2.0/24"
]

private_subnets = [
  "10.1.3.0/24",
  "10.1.4.0/24"
]

eks_cluster_name = "staging-eks-cluster"

node_instance_type = "t3.medium"

desired_capacity = 2
min_size = 1
max_size = 4
