#!/bin/bash
set -e

echo "Iniciando configuração da infraestrutura..."

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

# Definir função para tratamento de erros
handle_error() {
    local exit_code=$?
    local line_number=$1
    echo "❌ Erro na linha $line_number, código de saída: $exit_code"
    
    # Verificar se é um erro crítico que deve interromper o processo
    if [ "$2" == "critical" ]; then
        echo "⚠️ Erro crítico detectado. Interrompendo a configuração."
        exit $exit_code
    else
        echo "⚠️ Continuando com o restante da configuração..."
    fi
}

# Configurar trap para capturar erros
trap 'handle_error $LINENO' ERR

# Verificar disponibilidade do SSM
echo "Verificando disponibilidade do SSM nas instâncias..."
"$(dirname "$0")/check_ssm_availability.sh" || handle_error $LINENO "critical"

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

# Pulando configuração do Nominatim
echo "Pulando configuração do Nominatim por enquanto..."

# Configurar API Gateway
echo "Configurando API Gateway..."
configure_api_gateway || {
    echo "⚠️ Falha na configuração do API Gateway, mas continuando..."
}

# Verificar status final de todos os serviços
echo "Verificando status final dos serviços..."

# Função para verificar status de um serviço
check_service_status() {
    local service_name=$1
    local instance_id=$2
    
    echo "Verificando status de $service_name..."
    local check_cmd="systemctl is-active $service_name 2>/dev/null || echo 'inactive'"
    local command_id=$(execute_on_instance "$instance_id" "$check_cmd")
    local status=$(aws ssm get-command-invocation \
        --command-id "$command_id" \
        --instance-id "$instance_id" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "falha")
    
    if [[ "$status" == "active" ]]; then
        echo "✅ $service_name está ativo"
    else
        echo "⚠️ $service_name não está ativo (status: $status)"
    fi
}

# Verificar serviços específicos
redis_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=redis" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "redis-server" "$redis_id"

mongodb_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=mongodb" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "mongod" "$mongodb_id"

postgres_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=postgres" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "postgresql" "$postgres_id"

monitoring_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "grafana-server" "$monitoring_id"
check_service_status "prometheus" "$monitoring_id"

# Instalar Prometheus automaticamente
echo "Instalando Prometheus automaticamente..."
"$(dirname "$0")/install_prometheus.sh"
prometheus_status=$?

if [ $prometheus_status -eq 0 ]; then
    echo "✅ Prometheus instalado e configurado com sucesso"
else
    echo "⚠️ Falha na instalação do Prometheus, mas continuando..."
fi

echo "Configuração completa concluída!"
# Verificar status dos serviços
echo "Verificando status dos serviços..."
"$(dirname "$0")/check_services.sh"
service_status=$?

if [ $service_status -eq 0 ]; then
    echo "✅ Todos os serviços estão funcionando corretamente"
    echo "✅ Configuração concluída com sucesso!"
    exit 0
else
    echo "⚠️ Alguns serviços não estão funcionando corretamente"
    echo "⚠️ Configuração concluída com avisos!"
    exit $service_status
fi