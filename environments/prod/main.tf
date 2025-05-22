provider "aws" {
  region = var.aws_region
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = var.eks_cluster_name
  node_instance_type = var.node_instance_type
  desired_capacity   = var.node_desired_capacity
}

module "ec2_aux" {
  source     = "../../modules/ec2"
  instances  = var.auxiliary_instances
  vpc_id     = module.eks.vpc_id
  subnet_id  = module.eks.private_subnets[0]
}

module "gateway" {
  source           = "../../modules/apigateway"
  domain_name      = var.api_domain
  certificate_arn  = var.acm_certificate_arn
  mappings         = var.api_gateway_mappings
}