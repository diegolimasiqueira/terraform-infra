variable "project_name" {
  type        = string
  description = "Nome do projeto para prefixar recursos"
  default     = "easyprofind"
}

# KMS Key para criptografia
resource "aws_kms_key" "main" {
  description             = "KMS key para criptografia de dados"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "main" {
  name          = "alias/${var.project_name}-key"
  target_key_id = aws_kms_key.main.key_id
}

# IAM Role para aplicações
resource "aws_iam_role" "app_role" {
  name = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Política básica para aplicações
resource "aws_iam_policy" "app_policy" {
  name        = "${var.project_name}-app-policy"
  description = "Política para aplicações do ${var.project_name}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_policy_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.app_policy.arn
}

# Outputs
output "kms_key_id" {
  description = "ID da chave KMS"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "ARN da chave KMS"
  value       = aws_kms_key.main.arn
}

output "app_role_arn" {
  description = "ARN da role IAM para aplicações"
  value       = aws_iam_role.app_role.arn
}