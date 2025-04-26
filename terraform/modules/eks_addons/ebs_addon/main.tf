data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "eks_ebs_driver_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "eks_efs_driver_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:efs-csi-controller-sa"]
    }
  }
}

resource "aws_iam_role" "ebs_csi_role" {
  name               = "AmazonEKS_EBS_CSI_DriverRole-${var.environment}-${var.region}"
  description        = "IAM role to be used by a K8s to provision volume using EBS"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.eks_ebs_driver_policy.json
}

resource "aws_iam_role_policy_attachment" "ebs_policy_attachment" {
  role       = aws_iam_role.ebs_csi_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}


resource "aws_iam_role" "efs_csi_role" {
  name               = "AmazonEKS_EFS_CSI_DriverRole-${var.environment}-${var.region}"
  description        = "IAM role to be used by a K8s to provision volume using EFS"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.eks_efs_driver_policy.json
}

resource "aws_iam_role_policy_attachment" "efs_policy_attachment" {
  role       = aws_iam_role.efs_csi_role.name
  policy_arn = "arn:aws:iam::${local.account_id}:policy/AmazonEKS_EFS_CSI_Driver_Policy"
}


resource "aws_eks_addon" "example" {
  cluster_name                = "${var.name}-${var.environment}"
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = var.ebs-csi-addon_version
  resolve_conflicts_on_update = "PRESERVE"
  service_account_role_arn    = aws_iam_role.ebs_csi_role.arn
}