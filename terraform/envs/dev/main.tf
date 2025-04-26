module "network" {
  source          = "../../modules/network"
  environment     = var.environment
  region          = var.aws_region
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

module "iam" {
  source      = "../../modules/iam"
  environment = var.environment
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.eks_cluster_name
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.private_subnets
  environment        = var.environment
  node_instance_type = var.node_instance_type
  desired_capacity   = var.desired_capacity
  min_size           = var.min_size
  max_size           = var.max_size
  cluster_role_arn   = module.iam.eks_cluster_role_arn
  node_role_arn      = module.iam.eks_node_role_arn
}

