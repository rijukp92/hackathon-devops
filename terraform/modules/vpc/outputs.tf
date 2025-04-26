output "vpc_id" {
  description = "vpc_id"
  value       = module.vpc.vpc_id
}

output "vpc-security-group-ids" {
  description = "vpc-security-group-ids"
  value       = module.vpc.default_security_group_id
}

output "database_subnet_group_name" {
  description = "Database subnet group name"
  value       = module.vpc.database_subnet_group_name

}

output "vpc_private_subnets" {
  description = "vpc Private subnets"
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "Subnet IDs of database subnets"
  value       = module.vpc.database_subnets
}

output "vpc_public_subnets" {
  description = "vpc Public subnets"
  value       = module.vpc.public_subnets
}

