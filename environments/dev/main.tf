# VPC e rede (primeiro recurso a ser criado conforme ordem de provisionamento)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"
  
  name = "${var.project_name}-vpc"
  cidr = "10.0.0.0/16"
  
  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  
  enable_nat_gateway = true
  single_nat_gateway = true
  
  tags = local.common_tags
}

# EC2s auxiliares (segundo recurso a ser criado)
module "ec2_aux" {
  source     = "../../modules/ec2"
  instances  = var.auxiliary_instances
  vpc_id     = module.vpc.vpc_id
  subnet_id  = module.vpc.public_subnets[0]
  tags       = local.common_tags
}

# EKS com Node Group (terceiro recurso a ser criado)
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.eks_cluster_name
  node_instance_type = var.node_instance_type
  desired_capacity   = var.node_desired_capacity
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
}

# Addons do EKS (serão aplicados separadamente após o cluster estar pronto)
module "eks_addons" {
  source       = "../../modules/eks-addons"
  cluster_name = module.eks.cluster_name
}

# API Gateway com SSL e rotas (sexto recurso a ser criado)
module "gateway" {
  source           = "../../modules/apigateway"
  domain_name      = var.api_domain
  certificate_arn  = var.acm_certificate_arn
  mappings         = var.api_gateway_mappings
  stage_name       = var.environment
  region           = var.aws_region
}

# Fila SQS com permissões (sétimo recurso a ser criado)
module "messaging" {
  source     = "../../modules/messaging"
  queue_name = "geo-queue-${var.environment}"
  tags       = local.common_tags
}

# Segurança (IAM, KMS, etc.)
module "security" {
  source       = "../../modules/security"
  project_name = var.project_name
}

# Bucket S3 para logs do SSM
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-logs"
  tags   = local.common_tags
  
  # Não falhar se o bucket já existir
  lifecycle {
    prevent_destroy = true
    ignore_changes = all
  }
}

resource "aws_s3_bucket_versioning" "logs_versioning" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}