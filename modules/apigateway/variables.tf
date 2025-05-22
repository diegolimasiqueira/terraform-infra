variable "domain_name" {
  type        = string
  description = "Nome de domínio personalizado para o API Gateway"
}

variable "certificate_arn" {
  type        = string
  description = "ARN do certificado ACM para o domínio"
}

variable "mappings" {
  type        = map(string)
  description = "Mapeamentos de caminhos para o API Gateway"
}

variable "stage_name" {
  type        = string
  description = "Nome do estágio do API Gateway"
  default     = "dev"
}