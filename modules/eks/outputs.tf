output "cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint do cluster EKS"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Dados do certificado da autoridade do cluster"
  value       = module.eks.cluster_certificate_authority_data
}

output "cluster_iam_role_name" {
  description = "Nome do IAM role do cluster"
  value       = module.eks.cluster_iam_role_name
}

output "vpc_id" {
  description = "ID da VPC onde o cluster foi criado"
  value       = var.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = var.subnet_ids
}