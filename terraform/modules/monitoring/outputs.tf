output "grafana_endpoint" {
  value = module.managed_grafana.workspace_endpoint
}

output "prometheus_endpoint" {
  value = aws_prometheus_workspace.prometheus.prometheus_endpoint
}

output "prometheus_workspace_id" {
  value = aws_prometheus_workspace.prometheus.id
}

output "agent_irsa_role_arn" {
  value = aws_iam_role.agent_irsa_role.arn
}

output "workspace_api_keys" {
  value = module.managed_grafana.workspace_api_keys
}

output "admin_api_key" {
  value = module.managed_grafana.workspace_api_keys.admin.key
}

output "prometheus_write_access_policy_arn" {
  value = aws_iam_policy.write_amp_policy.arn
}

output "central_irsa_role_arn" {
  value = aws_iam_role.prometheus_central_ingest.arn
}

output "grafana_workspace_id" {
  value = module.managed_grafana.workspace_id
}