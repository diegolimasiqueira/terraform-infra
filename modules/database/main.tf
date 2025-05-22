variable "vpc_id" {
  type        = string
  description = "ID da VPC onde os bancos de dados serão criados"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs das subnets onde os bancos de dados serão criados"
}

# Security Group para PostgreSQL
resource "aws_security_group" "postgres" {
  name        = "postgres-sg"
  description = "Security Group para PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "PostgreSQL - Apenas VPC interna"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group para MongoDB
resource "aws_security_group" "mongodb" {
  name        = "mongodb-sg"
  description = "Security Group para MongoDB"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "MongoDB - Apenas VPC interna"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Outputs
output "postgres_sg_id" {
  description = "ID do Security Group do PostgreSQL"
  value       = aws_security_group.postgres.id
}

output "mongodb_sg_id" {
  description = "ID do Security Group do MongoDB"
  value       = aws_security_group.mongodb.id
}