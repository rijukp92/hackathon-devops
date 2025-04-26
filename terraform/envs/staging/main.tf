module "network" {
  source       = "../../modules/network"
  environment  = "dev"
  region       = var.aws_region
  vpc_cidr     = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
}

module "iam" {
  source      = "../../modules/iam"
  environment = "dev"
}

module "eks" {
  source         = "../../modules/eks"
  cluster_name   = "dev-cluster"
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.private_subnets
  environment    = "dev"
}
