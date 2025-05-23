#!/bin/bash
set -e

echo "Script de correção para problemas de instalação do Monitoring"

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

echo "Verificando e corrigindo instalação do Monitoring na instância $monitoring_id..."

# Verificar Grafana
grafana_cmd='set -e
if dpkg -l | grep -q grafana; then
    echo "Grafana está instalado"
    if systemctl is-active --quiet grafana-server; then
        echo "✅ Grafana está rodando"
    else
        echo "⚠️ Grafana não está rodando, iniciando..."
        sudo systemctl start grafana-server
        sudo systemctl enable grafana-server
        if systemctl is-active --quiet grafana-server; then
            echo "✅ Grafana iniciado com sucesso"
        else
            echo "❌ Falha ao iniciar Grafana"
        fi
    fi
else
    echo "❌ Grafana não está instalado, instalando..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add --batch --yes -
    echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
    sudo apt-get update
    echo "grafana-server grafana-server/start-on-boot boolean true" | sudo debconf-set-selections
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" grafana
    sudo systemctl start grafana-server
    sudo systemctl enable grafana-server
    echo "✅ Grafana instalado e iniciado"
fi'

echo "Verificando e corrigindo Grafana..."
grafana_id=$(execute_on_instance "$monitoring_id" "$grafana_cmd")
wait_for_command "$grafana_id" "$monitoring_id" "true"

# Verificar Prometheus
prometheus_cmd='set -e
if dpkg -l | grep -q prometheus; then
    echo "Prometheus está instalado"
    if systemctl is-active --quiet prometheus; then
        echo "✅ Prometheus está rodando"
    else
        echo "⚠️ Prometheus não está rodando, iniciando..."
        sudo systemctl start prometheus
        sudo systemctl enable prometheus
        if systemctl is-active --quiet prometheus; then
            echo "✅ Prometheus iniciado com sucesso"
        else
            echo "❌ Falha ao iniciar Prometheus"
        fi
    fi
else
    echo "❌ Prometheus não está instalado, instalando..."
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    
    # Pré-configurar todas as possíveis perguntas
    sudo debconf-set-selections <<EOF
prometheus prometheus/restart-services boolean true
prometheus prometheus/restart-without-asking boolean true
prometheus-node-exporter prometheus-node-exporter/restart-services boolean true
prometheus-node-exporter prometheus-node-exporter/restart-without-asking boolean true
smartmontools smartmontools/start_smartd boolean true
EOF
    
    # Instalar com opções não interativas
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" prometheus
    sudo systemctl start prometheus
    sudo systemctl enable prometheus
    echo "✅ Prometheus instalado e iniciado"
fi'

echo "Verificando e corrigindo Prometheus..."
prometheus_id=$(execute_on_instance "$monitoring_id" "$prometheus_cmd")
wait_for_command "$prometheus_id" "$monitoring_id" "true"

# Verificar status final
status_cmd='set -e
grafana_status=$(systemctl is-active grafana-server || echo "inactive")
prometheus_status=$(systemctl is-active prometheus || echo "inactive")

echo "Status do Grafana: $grafana_status"
echo "Status do Prometheus: $prometheus_status"

if [ "$grafana_status" = "active" ] && [ "$prometheus_status" = "active" ]; then
    echo "✅ Monitoring completo está funcionando corretamente"
    exit 0
else
    echo "⚠️ Alguns componentes do Monitoring não estão funcionando"
    exit 1
fi'

echo "Verificando status final do Monitoring..."
status_id=$(execute_on_instance "$monitoring_id" "$status_cmd")
wait_for_command "$status_id" "$monitoring_id" "true"

echo "Script de correção concluído!"