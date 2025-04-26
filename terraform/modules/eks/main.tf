provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
}

data "aws_caller_identity" "current" {}
data "aws_availability_zones" "available" {}
data "aws_ami" "eks_default" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }
}

locals {
  role_name_map = {
    "masters"     = "system:masters"
  }

  user_map = jsondecode(file("./modules/eks/users_map.json"))

  user_map_obj = flatten([
    for role_name, users in local.user_map : [
      for user in users : {
        userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/${user}"
        username = user
        groups   = tolist([local.role_name_map[role_name]])
      }
    ]
  ])
}


################################################################################
# EKS Module
################################################################################

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "20.30.1"
  cluster_name                             = "${var.name}-${var.environment}"
  cluster_version                          = var.cluster_version
  cluster_endpoint_public_access           = true
  vpc_id                                   = var.vpc_id
  subnet_ids                               = var.private_subnets
  enable_cluster_creator_admin_permissions = true

  self_managed_node_groups = {

    app_workers = {
      name            = "app-workers-${var.name}-${var.environment}"
      use_name_prefix = true

      subnet_ids             = var.private_subnets
      vpc_security_group_ids = [var.additional_security_group_ids]
      min_size               = var.app_min_size
      max_size               = var.app_max_size
      desired_size           = var.app_desired_size
      instance_type          = var.app_group_instance_type

      ami_id                          = data.aws_ami.eks_default.id
      bootstrap_extra_args            = "--kubelet-extra-args '--node-labels=role=apps'"
      pre_bootstrap_user_data         = var.pre_bootstrap_user_data
      post_bootstrap_user_data        = var.post_bootstrap_user_data
      launch_template_name            = "${var.name}-${var.environment}-app-workers-asg"
      launch_template_use_name_prefix = true
      launch_template_description     = "App-workers ASG launch template for ${var.name}-${var.environment}"
      enable_monitoring               = false
      create_iam_role                 = true
      iam_role_name                   = "${var.name}-${var.environment}-${var.region}-app-workers-role"
      iam_role_use_name_prefix        = false
      iam_role_description            = "App workers role for ${var.name}-${var.environment} in ${var.region}"
      iam_role_additional_policies = {
        AmazonEC2ContainerRegistryReadOnly = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
        additional                         = aws_iam_policy.additional.arn
      }

      timeouts = {
        create = "80m"
        update = "80m"
        delete = "80m"
      }
    }
  }
}

################################
#### IAM addition policies #####
################################

resource "aws_iam_policy" "additional" {
  name        = "${var.name}-${var.environment}-${var.region}-additional-policy"
  description = "Node additional policy for ${var.name}-${var.environment} in ${var.region}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}