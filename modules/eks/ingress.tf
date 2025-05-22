variable "install_ingress_controller" {
  type        = bool
  description = "Instalar o ALB Ingress Controller via Helm"
  default     = true
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

# Helm provider para instalar o ALB Ingress Controller
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
      command     = "aws"
    }
  }
}

# Kubernetes provider para criar recursos no cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", var.cluster_name]
    command     = "aws"
  }
}

# Instalação do ALB Ingress Controller via Helm
resource "helm_release" "alb_ingress_controller" {
  count      = var.install_ingress_controller ? 1 : 0
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  
  set {
    name  = "clusterName"
    value = var.cluster_name
  }
  
  set {
    name  = "serviceAccount.create"
    value = "true"
  }
  
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  
  depends_on = [module.eks]
}

# Ingress para os microserviços
resource "kubernetes_ingress_v1" "microservices" {
  count = var.install_ingress_controller ? 1 : 0
  metadata {
    name = "microservices-ingress"
    annotations = {
      "kubernetes.io/ingress.class"                  = "alb"
      "alb.ingress.kubernetes.io/scheme"             = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"        = "ip"
      "alb.ingress.kubernetes.io/healthcheck-path"   = "/health"
      "alb.ingress.kubernetes.io/healthcheck-port"   = "traffic-port"
      "alb.ingress.kubernetes.io/success-codes"      = "200"
    }
  }
  
  spec {
    dynamic "rule" {
      for_each = var.ingress_routes
      content {
        http {
          path {
            path = "/${rule.key}/*"
            path_type = "Prefix"
            backend {
              service {
                name = rule.value
                port {
                  number = 80
                }
              }
            }
          }
        }
      }
    }
  }
  
  depends_on = [helm_release.alb_ingress_controller]
}