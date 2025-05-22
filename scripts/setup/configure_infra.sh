#!/bin/bash
set -e

echo "Iniciando configuração da infraestrutura..."

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

# Verificar disponibilidade do SSM
"$(dirname "$0")/check_ssm_availability.sh"

# Aguardar instâncias estarem prontas
echo "Aguardando instâncias EC2 estarem prontas..."
aws ec2 wait instance-running --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=keycloak,redis,mongodb,postgres,monitoring,nominatim" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

# Configurar Keycloak
echo "Configurando Keycloak..."
configure_keycloak || {
    echo "⚠️ Falha na configuração do Keycloak, mas continuando com outros serviços..."
}

# Configurar Redis
echo "Configurando Redis..."
configure_redis || {
    echo "⚠️ Falha na configuração do Redis, mas continuando com outros serviços..."
}

# Configurar MongoDB
echo "Configurando MongoDB..."
configure_mongodb || {
    echo "⚠️ Falha na configuração do MongoDB, mas continuando com outros serviços..."
}

# Configurar PostgreSQL
echo "Configurando PostgreSQL..."
configure_postgres || {
    echo "⚠️ Falha na configuração do PostgreSQL, mas continuando com outros serviços..."
}

# Configurar Monitoring (Prometheus + Grafana)
echo "Configurando Monitoring..."
configure_monitoring || {
    echo "⚠️ Falha na configuração do Monitoring, mas continuando com outros serviços..."
}

# Configurar API Gateway
echo "Configurando API Gateway..."
configure_api_gateway || {
    echo "⚠️ Falha na configuração do API Gateway, mas continuando..."
}

echo "✅ Configuração concluída!"