###Data

data "aws_availability_zones" "available" {}

###VPC Creation

module "vpc" {
  source          = "./modules/vpc"
  environment     = var.environment
  name            = var.name
  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  db_subnets      = var.db_subnets
  azs             = data.aws_availability_zones.available.names
}

###Security group for worker nodes and DB

module "aws_security_group" {
  source      = "./modules/security_group"
  vpc_cidr    = var.vpc_cidr
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  name        = var.name
  depends_on  = [module.vpc]
}

module "eks" {
  source                        = "./modules/eks"
  environment                   = var.environment
  region                        = var.region
  name                          = var.name
  cluster_version               = var.cluster_version
  private_subnets               = module.vpc.vpc_private_subnets
  app_group_instance_type       = var.app_group_instance_type
  app_min_size                  = var.app_min_size
  app_max_size                  = var.app_max_size
  app_desired_size              = var.app_desired_size
  vpc_id                        = module.vpc.vpc_id
  additional_security_group_ids = module.aws_security_group.additional_security_group_ids
}

module "ecr" {
  source = "./modules/ecr"
}