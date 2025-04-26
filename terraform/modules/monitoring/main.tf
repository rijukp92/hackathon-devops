# This module creates workspaces for Amazon Managed Prometheus (AMP) and
# Amazon Managed Grafana (AMG). Also it deploys Grafana cloud agent to the cluster
# and sets up necessary permissions to push metrics to the AMP workspace
# as well as accessing AMG workspace.

module "managed_grafana" {
  source  = "terraform-aws-modules/managed-service-grafana/aws"
  version = "2.1.0"

  # Workspace
  name                      = var.grafana_workspace_name
  description               = "Centralized AWS Managed Grafana service"
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = ["AWS_SSO"]
  permission_type           = "SERVICE_MANAGED"
  data_sources              = ["CLOUDWATCH", "PROMETHEUS", "XRAY"]
  associate_license         = false
  grafana_version           = 10.4
  configuration = jsonencode({
    unifiedAlerting = {
      enabled = true
    }
  })

  workspace_api_keys = {
    admin = {
      key_name        = "admin"
      key_role        = "ADMIN"
      seconds_to_live = 3600 * 24 * 30
    }
  }

  role_associations = {
    "ADMIN" = {
      "user_ids" = [
        "94083478-5001-7049-d1bc-654c86c0751e" #Dashborad Editor 
      ]
    },
    "VIEWER" = {
       "user_ids" = [
         "34c85458-e0d1-7089-5435-a0faa60859d1" #Dashboard Viewer
       ]
     }
  }
}

resource "aws_prometheus_workspace" "prometheus" {
  alias = var.prometheus_workspace_name
  tags  = {
    Environment = var.environment
  }
}

# Now we need to deploy a grafana cloud agent with necessary permissions to send
# metrics to the AMP workspace. First we will create the IAM role to be associated
# with a service account for the agent running in the cluster.
#
# Setup a trust policy designed for a specific combination of K8s service account
# and namespace to sign in from a Kubernetes cluster which hosts the OIDC Idp.
# This will permit the grafana-agent service account to sign in to AMP workspace.

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_iam_policy_document" "agent-assume-role-policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.account_id}:oidc-provider/${var.oidc_provider}"]
    }

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:grafana-agent"]
    }
  }
}

data "aws_iam_policy_document" "write_amp_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/EKS-AMP-Central-Role"]
  }
}

resource "aws_iam_policy" "write_amp_policy" {
  name   = "prometheus-remote-ingest-${var.environment}-${var.region}"
  path   = "/"
  policy = data.aws_iam_policy_document.write_amp_policy_doc.json
}

resource "aws_iam_role" "agent_irsa_role" {
  name               = "prometheus-remote-ingest-${var.environment}-${var.region}"
  description        = "IAM role to be used by a K8s service account with write access to AMP"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.agent-assume-role-policy.json
}

resource "aws_iam_role_policy_attachment" "agent_irsa_role_policy_attachment" {
  role       = aws_iam_role.agent_irsa_role.name
  policy_arn = aws_iam_policy.write_amp_policy.arn
}

data "aws_iam_policy_document" "prometheus_central_ingest" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = [
        "arn:aws:iam::${local.account_id}:role/prometheus-remote-ingest-${var.environment}-${var.region}"
      ]
      type = "AWS"
    }
  }
}

resource "aws_iam_role" "prometheus_central_ingest" {
  name               = "EKS-AMP-Central-Role"
  assume_role_policy = data.aws_iam_policy_document.prometheus_central_ingest.json
}

resource "aws_iam_role_policy_attachment" "prometheus_central_ingest" {
  role       = aws_iam_role.prometheus_central_ingest.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonPrometheusRemoteWriteAccess"
}