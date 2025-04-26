module "vpc" {
  source               = "terraform-aws-modules/vpc/aws"
  version              = "5.16.0"
  name                 = "${var.name}-${var.environment}"
  cidr                 = var.vpc_cidr
  azs                  = var.azs
  private_subnets      = var.private_subnets
  public_subnets       = var.public_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  create_database_subnet_group = true
  database_subnet_group_name   = "${var.name}-db-subnet-${var.environment}"
  database_subnets             = var.db_subnets

  tags = {
    "kubernetes.io/cluster/${var.name}-${var.environment}" = "shared"
    Environment                                            = var.environment
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${var.name}-${var.environment}" = "shared"
    "kubernetes.io/role/elb"                               = "1"
    "public"                                               = "true"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.name}-${var.environment}" = "shared"
    "kubernetes.io/role/internal-elb"                      = "1"
    "public"                                               = "false"
  }
}
