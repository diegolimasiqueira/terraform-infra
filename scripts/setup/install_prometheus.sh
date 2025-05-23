#!/bin/bash
set -e

echo "Instalando Prometheus na instância de monitoring..."

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

# Obter ID da instância de monitoring
monitoring_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -z "$monitoring_id" ]; then
    echo "❌ Instância de monitoring não encontrada"
    exit 1
fi

# Verificar se o Prometheus já está instalado
echo "Verificando se o Prometheus já está instalado..."
prometheus_check_cmd="dpkg -l | grep -q prometheus && echo 'installed' || echo 'not-installed'"
prometheus_check_id=$(execute_on_instance "$monitoring_id" "$prometheus_check_cmd")
prometheus_installed=$(aws ssm get-command-invocation \
    --command-id "$prometheus_check_id" \
    --instance-id "$monitoring_id" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null || echo "not-installed")

if [[ "$prometheus_installed" == *"installed"* ]]; then
    echo "Prometheus já está instalado. Verificando status..."
    prometheus_status_cmd="systemctl is-active prometheus || echo 'inactive'"
    prometheus_status_id=$(execute_on_instance "$monitoring_id" "$prometheus_status_cmd")
    prometheus_status=$(aws ssm get-command-invocation \
        --command-id "$prometheus_status_id" \
        --instance-id "$monitoring_id" \
        --query "StandardOutputContent" \
        --output text 2>/dev/null || echo "inactive")
    
    if [[ "$prometheus_status" == "active" ]]; then
        echo "✅ Prometheus já está ativo"
        exit 0
    else
        echo "Prometheus está instalado mas não está ativo. Iniciando serviço..."
        prometheus_start_cmd="sudo systemctl start prometheus && sudo systemctl enable prometheus"
        prometheus_start_id=$(execute_on_instance "$monitoring_id" "$prometheus_start_cmd")
        wait_for_command "$prometheus_start_id" "$monitoring_id"
    fi
else
    echo "Prometheus não está instalado. Instalando..."
    prometheus_install_cmd='set -e
export DEBIAN_FRONTEND=noninteractive
echo "Atualizando pacotes..."
sudo apt-get update
echo "Pré-configurando respostas para pacotes..."
# Pré-configurar todas as possíveis perguntas
sudo debconf-set-selections <<EOF
prometheus prometheus/restart-services boolean true
prometheus prometheus/restart-without-asking boolean true
prometheus-node-exporter prometheus-node-exporter/restart-services boolean true
prometheus-node-exporter prometheus-node-exporter/restart-without-asking boolean true
smartmontools smartmontools/start_smartd boolean true
EOF
echo "Instalando Prometheus..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" prometheus
echo "Iniciando serviços..."
sudo systemctl start prometheus
sudo systemctl enable prometheus
echo "Prometheus instalado e iniciado"'
    prometheus_install_id=$(execute_on_instance "$monitoring_id" "$prometheus_install_cmd")
    wait_for_command "$prometheus_install_id" "$monitoring_id"
fi

# Verificar se a instalação foi bem-sucedida
prometheus_verify_cmd="systemctl is-active prometheus || echo 'inactive'"
prometheus_verify_id=$(execute_on_instance "$monitoring_id" "$prometheus_verify_cmd")
prometheus_status=$(aws ssm get-command-invocation \
    --command-id "$prometheus_verify_id" \
    --instance-id "$monitoring_id" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null || echo "inactive")

if [[ "$prometheus_status" == "active" ]]; then
    echo "✅ Prometheus instalado e ativo"
    exit 0
else
    echo "❌ Falha ao instalar ou iniciar o Prometheus"
    exit 1
fi