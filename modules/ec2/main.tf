resource "aws_security_group" "ec2_sg" {
  name   = "ec2_sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.ssh_allowed_cidrs
  }
  
  # Keycloak
  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["200.181.123.18/32", "10.0.0.0/16"]
    description = "Keycloak HTTPS - Seu IP e VPC interna"
  }
  
  # Keycloak HTTP (fallback)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["200.181.123.18/32", "10.0.0.0/16"]
    description = "Keycloak HTTP - Seu IP e VPC interna"
  }
  
  # Grafana
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["200.181.123.18/32", "10.0.0.0/16"]
    description = "Grafana Web UI - Seu IP e VPC interna"
  }
  
  # Redis
  ingress {
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
    description = "Redis - Apenas VPC interna"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ec2_sg"
    Project     = "EasyProFind"
    Environment = "dev"
    Owner       = "diego"
  }
}

# IAM Role para SSM (simplificada)
resource "aws_iam_role" "ssm_role" {
  name = "ec2_ssm_role"

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

# Política para SSM (apenas o essencial)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile (simplificado)
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# Bucket S3 para logs do SSM (simplificado)
resource "aws_s3_bucket" "ssm_logs" {
  bucket = "easyprofind-logs"
}

# Política de bucket (simplificada)
resource "aws_s3_bucket_policy" "ssm_logs_policy" {
  bucket = aws_s3_bucket.ssm_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "ssm.amazonaws.com"
        }
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.ssm_logs.arn,
          "${aws_s3_bucket.ssm_logs.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_instance" "aux" {
  for_each = var.instances

  ami                         = each.value.ami
  instance_type               = each.value.instance_type
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm_profile.name
  
  root_block_device {
    volume_size = each.value.disk_size
    volume_type = "gp3"
  }

  tags = merge({
    Name        = each.value.name
    Project     = "EasyProFind"
    Environment = "dev"
    Owner       = "diego"
  }, var.tags)
}

# Elastic IP apenas para keycloak, nominatim e monitoring
resource "aws_eip" "service" {
  for_each = {
    for k, v in var.instances : k => v
    if v.name == "keycloak" || v.name == "nominatim" || v.name == "monitoring"
  }
  instance = aws_instance.aux[each.key].id
  domain   = "vpc"
  tags = {
    Name = "eip-${each.value.name}"
  }
}

variable "instances" {
  type = map(object({
    ami           = string
    instance_type = string
    name          = string
    disk_size     = number
  }))
  validation {
    condition     = alltrue([for inst in var.instances : can(regex("^ami-", inst.ami))])
    error_message = "Todos os AMIs devem começar com 'ami-'."
  }
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "vpc_id" { type = string }
variable "subnet_id" {
  type        = string
  description = "ID da subnet onde as instâncias serão criadas"
}
variable "ssh_allowed_cidrs" {
  type        = list(string)
  default     = ["200.181.123.18/32"]
  description = "CIDRs permitidos para acesso SSH"
}