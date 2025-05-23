variable "domain_name" {
  type        = string
  description = "Nome de domínio personalizado para a API Gateway"
}

variable "certificate_arn" {
  type        = string
  description = "ARN do certificado ACM para o domínio personalizado"
}

variable "mappings" {
  type        = map(string)
  description = "Mapeamentos de caminhos para a API Gateway"
}

variable "stage_name" {
  type        = string
  description = "Nome do stage da API Gateway"
  default     = "dev"
}

variable "region" {
  type        = string
  description = "Região da AWS onde a API Gateway está sendo criada"
  default     = "us-east-1"
}