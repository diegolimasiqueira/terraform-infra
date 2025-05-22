#!/bin/bash
REGION="us-east-1"
echo "Buscando dados da infraestrutura..."

# Buscar IP do Keycloak
echo "Buscando IP do Keycloak..."
KEYCLOAK_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=keycloak" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)
echo "KEYCLOAK_IP=$KEYCLOAK_IP"

# Buscar IP do Nominatim
echo "Buscando IP do Nominatim..."
NOMINATIM_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=nominatim" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)
echo "NOMINATIM_IP=$NOMINATIM_IP"

# Buscar IP do Monitoring
echo "Buscando IP do Monitoring..."
MONITORING_IP=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].PrivateIpAddress" \
    --output text)
echo "MONITORING_IP=$MONITORING_IP"

# Buscar dados do EKS
echo "Buscando dados do EKS..."
CLUSTER_NAME=$(aws eks list-clusters --query "clusters[0]" --output text)
echo "CLUSTER_NAME=$CLUSTER_NAME"

# Criar arquivo de configuração
echo "Criando arquivo de configuração..."
cat > ../../infra-config.sh << EOF
#!/bin/bash
# Configurações da Infraestrutura
REGION="us-east-1"
CLUSTER_NAME="$CLUSTER_NAME"
KEYCLOAK_IP="$KEYCLOAK_IP"
NOMINATIM_IP="$NOMINATIM_IP"
MONITORING_IP="$MONITORING_IP"
# Exportar variáveis
export REGION
export CLUSTER_NAME
export KEYCLOAK_IP
export NOMINATIM_IP
export MONITORING_IP
EOF
chmod +x ../../infra-config.sh
echo "Arquivo de configuração criado: infra-config.sh"
echo "Para usar, execute: source infra-config.sh"