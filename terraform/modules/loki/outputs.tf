output "loki_data_bucket_name" {
  description = "Loki data bucket name"
  value       = aws_s3_bucket.loki-data.bucket
}

output "loki-irsa-role-arn" {
  description = "IAM Role ARN for loki Service account"
  value       = aws_iam_role.loki.arn 
}
