variable "install_ingress_controller" {
  type        = bool
  description = "Instalar o ALB Ingress Controller via Helm"
  default     = false  # Alterado para false por padrão
}

variable "ingress_routes" {
  type        = map(string)
  description = "Rotas de Ingress para os microserviços"
  default = {
    "bff"              = "bff-service"
    "ms-geo"           = "ms-geo-service"
    "ms-consumers"     = "ms-consumers-service"
    "ms-professionals" = "ms-professionals-service"
    "ms-rates"         = "ms-rates-service"
  }
}