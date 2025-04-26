resource "aws_security_group" "worker_group" {
  name_prefix = "${var.name}-${var.environment}-workergroup-sg"
  vpc_id      = var.vpc_id
  description = "SG for ${var.environment} worker group"

  ingress {
    from_port   = 0
    to_port     = 50051
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = {
    Environment = var.environment
  }
}

resource "aws_security_group" "db_security" {
  name_prefix = "${var.name}-${var.environment}-db-sg"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_group.id]
  }

  ingress {
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.worker_group.id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Environment = var.environment
  }
  depends_on = [aws_security_group.worker_group]
}
