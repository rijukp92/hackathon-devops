output "additional_security_group_ids" {
  description = "Additional Security group ids"
  value       = aws_security_group.worker_group.id
}

output "db_security_group_ids" {
  description = "Additional Security group ids"
  value       = aws_security_group.db_security.id
}