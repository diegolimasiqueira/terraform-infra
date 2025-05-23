aws_region = "us-east-1"
project_name = "easyprofind"
environment = "dev"
eks_cluster_name = "easyprofind-dev-cluster"
node_instance_type = "t3.small"
node_desired_capacity = 1
key_name = "easyprofind-key"

api_domain = "api.easyprofind.com"
# Substitua pelo ARN real do seu certificado na mesma conta
acm_certificate_arn = "arn:aws:acm:us-east-1:894450282722:certificate/222dcb0a-cba7-424b-8973-fc6060194a05"

api_gateway_mappings = {
  "monitoring" = "monitoring-endpoint"
  "redis"      = "redis-endpoint"
  "nominatim"  = "nominatim-endpoint"
  "bff"        = "bff-endpoint"
  "ms-geo"     = "ms-geo-endpoint"
  "ms-consumers" = "ms-consumers-endpoint"
  "ms-professionals" = "ms-professionals-endpoint"
  "ms-rates"   = "ms-rates-endpoint"
}

auxiliary_instances = {
  keycloak = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "keycloak"
    disk_size     = 8
  },
  nominatim = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "nominatim"
    disk_size     = 55
  },
  monitoring = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "monitoring"
    disk_size     = 8
  },
  redis = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "redis"
    disk_size     = 8  # Aumentado para 8GB conforme requisito mínimo do snapshot
  },
  postgres = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "postgres"
    disk_size     = 8
  },
  mongodb = {
    ami           = "ami-0c7217cdde317cfec"  # Amazon Linux 2023
    instance_type = "t3.small"
    name          = "mongodb"
    disk_size     = 8
  }
}