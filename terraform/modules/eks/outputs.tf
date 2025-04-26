output "oidc_provider" {
  description = "EKS cluster OIDC provider."
  value       = join("/", slice(split("/", module.eks.oidc_provider_arn), 1, 4))
}
