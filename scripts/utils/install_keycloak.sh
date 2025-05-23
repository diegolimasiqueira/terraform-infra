#!/bin/bash
set -e

# Configurar ambiente não interativo
export DEBIAN_FRONTEND=noninteractive

# Atualizar pacotes
echo "Atualizando pacotes..."
sudo apt-get update

# Instalar OpenJDK 17
echo "Instalando OpenJDK 17..."
sudo apt-get install -y openjdk-17-jdk

# Baixar e instalar Keycloak
echo "Baixando Keycloak..."
wget -q https://github.com/keycloak/keycloak/releases/download/22.0.5/keycloak-22.0.5.tar.gz

echo "Extraindo Keycloak..."
mkdir -p /home/ubuntu/keycloak-22.0.5
tar xzf keycloak-22.0.5.tar.gz --strip-components=1 -C /home/ubuntu/keycloak-22.0.5

echo "Configurando Keycloak..."
cd /home/ubuntu/keycloak-22.0.5/bin
sudo chmod +x kc.sh

echo "Iniciando Keycloak..."
nohup ./kc.sh start-dev --https-port=8443 --http-relative-path=/auth > /tmp/keycloak.log 2>&1 &

echo "Verificando se o Keycloak iniciou..."
sleep 15
if ps aux | grep -v grep | grep -E "keycloak|kc.sh" > /dev/null; then
    echo "Keycloak iniciado com sucesso"
    exit 0
else
    echo "Erro ao iniciar Keycloak. Verifique /tmp/keycloak.log"
    exit 1
fi