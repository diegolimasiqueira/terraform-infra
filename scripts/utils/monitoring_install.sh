#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Instalar dependências
echo "Instalando dependências..."
sudo apt-get update
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" apt-transport-https software-properties-common wget curl gnupg

# Instalar Grafana
echo "Instalando Grafana..."
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add --batch --yes -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee /etc/apt/sources.list.d/grafana.list
sudo apt-get update
echo "grafana-server grafana-server/start-on-boot boolean true" | sudo debconf-set-selections
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Verificar status do Grafana
echo "Status do Grafana:"
sudo systemctl status grafana-server --no-pager || true

# Instalar Prometheus via apt
echo "Instalando Prometheus..."
wget -q -O - https://s3-eu-west-1.amazonaws.com/deb.robustperception.io/41EFC99D.gpg | sudo apt-key add --batch --yes -
echo "deb https://packages.robustperception.io/deb stable main" | sudo tee /etc/apt/sources.list.d/prometheus.list
sudo apt-get update
sudo apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" prometheus
sudo systemctl start prometheus
sudo systemctl enable prometheus

# Verificar status do Prometheus
echo "Status do Prometheus:"
sudo systemctl status prometheus --no-pager || true

echo "Monitoring instalado e configurado com sucesso"