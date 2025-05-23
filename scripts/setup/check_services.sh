#!/bin/bash
set -e

echo "Verificando status dos serviços críticos..."

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

# Função para verificar status de um serviço
check_service_status() {
    local service_name=$1
    local instance_id=$2
    local critical=$3
    
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
        return 0
    else
        echo "⚠️ $service_name não está ativo (status: $status)"
        if [[ "$critical" == "true" ]]; then
            echo "Serviço crítico não está ativo. Tentando reiniciar..."
            local restart_cmd="sudo systemctl restart $service_name"
            local restart_id=$(execute_on_instance "$instance_id" "$restart_cmd")
            wait_for_command "$restart_id" "$instance_id" "true"
            
            # Verificar novamente após reiniciar
            local recheck_cmd="systemctl is-active $service_name 2>/dev/null || echo 'inactive'"
            local recheck_id=$(execute_on_instance "$instance_id" "$recheck_cmd")
            local recheck_status=$(aws ssm get-command-invocation \
                --command-id "$recheck_id" \
                --instance-id "$instance_id" \
                --query "StandardOutputContent" \
                --output text 2>/dev/null || echo "falha")
                
            if [[ "$recheck_status" == "active" ]]; then
                echo "✅ $service_name reiniciado com sucesso"
                return 0
            else
                echo "❌ Falha ao reiniciar $service_name"
                return 1
            fi
        fi
        return 1
    fi
}

# Verificar serviços específicos
redis_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=redis" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "redis-server" "$redis_id" "true"

mongodb_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=mongodb" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "mongod" "$mongodb_id" "true"

postgres_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=postgres" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "postgresql" "$postgres_id" "true"

monitoring_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)
check_service_status "grafana-server" "$monitoring_id" "true"

# Verificar se o Prometheus está instalado antes de verificar seu status
prometheus_check_cmd="dpkg -l | grep -q prometheus && echo 'installed' || echo 'not-installed'"
prometheus_check_id=$(execute_on_instance "$monitoring_id" "$prometheus_check_cmd")
prometheus_installed=$(aws ssm get-command-invocation \
    --command-id "$prometheus_check_id" \
    --instance-id "$monitoring_id" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null || echo "not-installed")

if [[ "$prometheus_installed" == *"installed"* ]]; then
    check_service_status "prometheus" "$monitoring_id" "true"
else
    echo "⚠️ Prometheus não está instalado. Será instalado posteriormente."
fi

# Verificar se todos os serviços críticos estão funcionando
echo "Verificando se todos os serviços críticos estão funcionando..."
all_services_ok=true

for service in "redis-server:$redis_id" "mongod:$mongodb_id" "postgresql:$postgres_id" "grafana-server:$monitoring_id"; do
    service_name=$(echo $service | cut -d':' -f1)
    instance_id=$(echo $service | cut -d':' -f2)
    
    check_cmd="systemctl is-active $service_name 2>/dev/null || echo 'inactive'"
    check_id=$(execute_on_instance "$instance_id" "$check_cmd")
    status=$(aws ssm get-command-invocation \
        --command-id "$check_id" \
        --instance-id "$instance_id" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "falha")
    
    if [[ "$status" != "active" ]]; then
        all_services_ok=false
        echo "❌ Serviço crítico $service_name não está ativo"
    fi
done

if $all_services_ok; then
    echo "✅ Todos os serviços críticos estão funcionando corretamente"
    exit 0
else
    echo "⚠️ Alguns serviços críticos não estão funcionando corretamente"
    exit 1
fi