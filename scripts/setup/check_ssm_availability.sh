#!/bin/bash
set -e

echo "Verificando disponibilidade do SSM nas instâncias..."

# Obter IDs das instâncias
instance_ids=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=keycloak,redis,mongodb,postgres,monitoring,nominatim" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

# Verificar cada instância
for instance_id in $instance_ids; do
    instance_name=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query "Reservations[].Instances[].Tags[?Key=='Name'].Value" \
        --output text)
    
    echo "Verificando SSM para instância $instance_name ($instance_id)..."
    
    max_attempts=30
    attempt=0
    while [ $attempt -lt $max_attempts ]; do
        status=$(aws ssm describe-instance-information \
            --filters "Key=InstanceIds,Values=$instance_id" \
            --query "InstanceInformationList[0].PingStatus" \
            --output text 2>/dev/null || echo "UNKNOWN")
        
        if [ "$status" = "Online" ]; then
            echo "✅ Instância $instance_name ($instance_id) está pronta para SSM"
            break
        fi
        
        attempt=$((attempt + 1))
        echo "⏳ Aguardando SSM ficar disponível na instância $instance_name... ($attempt/$max_attempts)"
        sleep 10
    done
    
    if [ $attempt -eq $max_attempts ]; then
        echo "❌ Timeout aguardando SSM na instância $instance_name ($instance_id)"
        echo "Verifique se o agente SSM está instalado e se a instância tem acesso à internet."
        exit 1
    fi
done

echo "✅ Todas as instâncias estão prontas para SSM"