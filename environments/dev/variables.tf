variable "aws_region" {
  type        = string
  description = "Região da AWS onde os recursos serão criados"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto para prefixar recursos"
  default     = "easyprofind"
}

variable "environment" {
  type        = string
  description = "Ambiente de implantação (dev, staging, prod)"
  default     = "dev"
}

variable "eks_cluster_name" {
  type        = string
  description = "Nome do cluster EKS"
  default     = "easyprofind-dev-cluster"
}

variable "node_instance_type" {
  type        = string
  description = "Tipo de instância para os nós do EKS"
  default     = "t3.small"
}

variable "node_desired_capacity" {
  type        = number
  description = "Número desejado de nós no cluster EKS"
  default     = 1
}

variable "auxiliary_instances" {
  type = map(object({
    ami           = string
    instance_type = string
    name          = string
    disk_size     = number
  }))
  description = "Mapa de instâncias EC2 auxiliares a serem criadas"
}

variable "api_domain" {
  type        = string
  description = "Domínio personalizado para o API Gateway"
}

variable "acm_certificate_arn" {
  type        = string
  description = "ARN do certificado ACM para o domínio da API"
}

variable "api_gateway_mappings" {
  type        = map(string)
  description = "Mapeamentos de caminhos para o API Gateway"
}

variable "key_name" { 
  type        = string 
  description = "Nome da chave SSH para acesso às instâncias EC2"
}