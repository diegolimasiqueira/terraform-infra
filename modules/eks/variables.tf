variable "cluster_name" {
  type        = string
  description = "Nome do cluster EKS"
}

variable "cluster_version" {
  type        = string
  description = "Versão do Kubernetes para o cluster EKS"
  default     = "1.32"
  validation {
    condition     = can(regex("^1\\.(2[0-9]|3[0-9])$", var.cluster_version))
    error_message = "A versão do cluster deve estar entre 1.20 e 1.39."
  }
}

variable "node_instance_type" {
  type        = string
  description = "Tipo de instância para os nós do EKS"
  default     = "t3.small"
}

variable "desired_capacity" {
  type        = number
  description = "Número desejado de nós no cluster EKS"
  default     = 1
}

variable "vpc_id" {
  type        = string
  description = "ID da VPC onde o cluster será criado"
}

variable "subnet_ids" {
  type        = list(string)
  description = "IDs das subnets onde o cluster será criado"
}

variable "enable_irsa" {
  type        = bool
  description = "Habilitar IRSA (IAM Roles for Service Accounts)"
  default     = true
}