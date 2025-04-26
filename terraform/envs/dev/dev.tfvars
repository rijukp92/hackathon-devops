aws_region = "us-east-1"

environment = "hackathon-devops-dev"

vpc_cidr = "10.0.0.0/16"

public_subnets = [
  "10.0.1.0/24",
  "10.0.2.0/24"
]

private_subnets = [
  "10.0.3.0/24",
  "10.0.4.0/24"
]

eks_cluster_name = "hackathon-devops-dev-eks-cluster"

node_instance_type = "t3.medium"

desired_capacity = 2
min_size = 1
max_size = 3
