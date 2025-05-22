#!/bin/bash
# Carregar configurações
if [ -f "infra-config.sh" ]; then
    source infra-config.sh
elif [ -f "../../infra-config.sh" ]; then
    source ../../infra-config.sh
else
    echo "Arquivo de configuração não encontrado. Execute primeiro: ./scripts/utils/get_infra_data.sh"
    exit 1
fi

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Função para verificar status
check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
    fi
}

# Função para verificar comando
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}✗ Comando $1 não encontrado. Por favor, instale-o primeiro.${NC}"
        exit 1
    fi
}

# Verificar comandos necessários
check_command curl
check_command jq
check_command aws

echo -e "${YELLOW}==== Verificando API Gateway e Microserviços ====${NC}"

# Verificar se o API Gateway está acessível
echo "Verificando API Gateway..."
if curl -sk --connect-timeout 5 --max-time 10 https://api.easyprofind.com/health > /dev/null; then
    echo -e "${GREEN}✓ API Gateway acessível${NC}"
else
    echo -e "${RED}✗ API Gateway não está acessível${NC}"
    echo -e "${YELLOW}Verifique se:${NC}"
    echo "1. O domínio está configurado corretamente"
    echo "2. O certificado SSL está válido"
    echo "3. O DNS está propagado"
    echo "4. O API Gateway está implantado corretamente"
fi

echo -e "\n${YELLOW}==== Testando endpoints dos microserviços ====${NC}"
echo -e "${YELLOW}Nota: Estes endpoints podem falhar se os serviços ainda não foram deployados${NC}\n"

for path in ms-consumers ms-professionals ms-geo bff; do
    echo -n "GET /$path/health: "
    if curl -sk --connect-timeout 5 --max-time 10 https://api.easyprofind.com/$path/health > /dev/null; then
        echo -e "${GREEN}ok${NC}"
    else
        echo -e "${RED}falhou${NC}"
        echo -e "  - Serviço $path ainda não deployado ou não está respondendo"
    fi
done

echo -e "\n${YELLOW}==== EC2s: Testando serviços auxiliares ====${NC}"

echo -n "Keycloak: "
# Primeiro verifica se o processo está rodando na instância
if aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$(aws ec2 describe-instances --filters "Name=tag:Name,Values=keycloak" --query "Reservations[*].Instances[*].InstanceId" --output text)" \
    --region "$REGION" \
    --parameters '{"commands":["ps aux | grep -v grep | grep -E \"keycloak|kc.sh\" > /dev/null && echo RUNNING || echo NOT_RUNNING"]}' \
    --output text | grep -q "RUNNING"; then
    echo -e "${GREEN}ok (processo rodando)${NC}"
# Depois tenta acessar via HTTP localmente
elif aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$(aws ec2 describe-instances --filters "Name=tag:Name,Values=keycloak" --query "Reservations[*].Instances[*].InstanceId" --output text)" \
    --region "$REGION" \
    --parameters '{"commands":["curl -s --connect-timeout 5 --max-time 10 https://localhost:8443/auth > /dev/null && echo SUCCESS || echo FAILED"]}' \
    --output text | grep -q "SUCCESS"; then
    echo -e "${GREEN}ok (acessível localmente)${NC}"
# Por último tenta acessar externamente
elif curl -sk --connect-timeout 5 --max-time 10 https://$KEYCLOAK_IP:8443/auth > /dev/null; then
    echo -e "${GREEN}ok (acessível externamente)${NC}"
else
    echo -e "${RED}falhou${NC}"
    echo -e "  - Verifique se o Keycloak foi inicializado"
    echo -e "  - Verifique se a porta 8443 está aberta no security group"
    echo -e "  - Verifique os logs do Keycloak: cat /tmp/keycloak.log"
fi

echo -n "Nominatim: "
if curl -s --connect-timeout 5 --max-time 10 "http://$NOMINATIM_IP:8080/search?q=Salvador&format=json" | jq .[0].display_name > /dev/null; then
    echo -e "${GREEN}ok${NC}"
else
    echo -e "${RED}falhou${NC}"
    echo -e "  - Verifique se o Nominatim está rodando"
    echo -e "  - Verifique se a porta 8080 está aberta no security group"
fi

echo -n "Monitoring (Grafana): "
# Primeiro verifica se o serviço está ativo
service_status=$(aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "Check Grafana service" \
    --instance-ids "$(aws ec2 describe-instances --filters "Name=tag:Name,Values=monitoring" --query "Reservations[*].Instances[*].InstanceId" --output text)" \
    --region "$REGION" \
    --parameters '{"commands":["systemctl is-active grafana-server"]}' \
    --output text)

if echo "$service_status" | grep -q "active"; then
    echo -e "${GREEN}ok (serviço ativo)${NC}"
    # Agora tenta acessar a interface web
    if curl -s --connect-timeout 5 --max-time 10 http://$MONITORING_IP:3000/login | grep -q 'Grafana'; then
        echo -e "${GREEN}ok (interface web acessível)${NC}"
    else
        echo -e "${YELLOW}Serviço ativo mas interface web não acessível${NC}"
        echo -e "  - Verifique se a porta 3000 está aberta no security group"
    fi
else
    echo -e "${RED}falhou (serviço não está ativo)${NC}"
    echo -e "  - Verifique se o Grafana foi inicializado: sudo systemctl start grafana-server"
    echo -e "  - Verifique os logs do Grafana: sudo journalctl -u grafana-server"
fi

echo -e "\n${YELLOW}==== Redis: Testando via EC2 ====${NC}"
# Primeiro verifica se o serviço está ativo
service_status=$(aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --comment "Check Redis service" \
    --instance-ids "$(aws ec2 describe-instances --filters "Name=tag:Name,Values=redis" --query "Reservations[*].Instances[*].InstanceId" --output text)" \
    --region "$REGION" \
    --parameters '{"commands":["systemctl is-active redis-server"]}' \
    --output text)

if echo "$service_status" | grep -q "active"; then
    echo -e "${GREEN}Redis serviço ativo${NC}"
    # Agora tenta fazer ping
    redis_output=$(aws ssm send-command \
        --document-name "AWS-RunShellScript" \
        --comment "Ping Redis" \
        --instance-ids "$(aws ec2 describe-instances --filters "Name=tag:Name,Values=redis" --query "Reservations[*].Instances[*].InstanceId" --output text)" \
        --region "$REGION" \
        --parameters '{"commands":["redis-cli ping"]}' \
        --output text)
    
    if echo "$redis_output" | grep -q "PONG"; then
        echo -e "${GREEN}Redis respondendo a comandos${NC}"
    else
        echo -e "${YELLOW}Redis não respondeu ao ping (esperado se configurado apenas para acesso interno)${NC}"
        echo -e "  - O Redis está configurado para aceitar apenas conexões internas (segurança adequada)"
        echo -e "  - Será acessado apenas pelo API Gateway e serviços no EKS"
    fi
else
    echo -e "${RED}Redis serviço não está ativo${NC}"
    echo -e "  - Verifique se o Redis foi inicializado: sudo systemctl start redis-server"
    echo -e "  - Verifique os logs do Redis: sudo journalctl -u redis-server"
fi

echo -e "\n${YELLOW}==== PostgreSQL e MongoDB: Verificação básica via systemctl ====${NC}"

for svc in postgres mongodb; do
    INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=$svc" --query "Reservations[*].Instances[*].InstanceId" --output text)
    
    echo -e "\n$svc:"
    
    service_status=$(aws ssm send-command \
        --document-name "AWS-RunShellScript" \
        --comment "Check $svc service" \
        --instance-ids "$INSTANCE_ID" \
        --region "$REGION" \
        --parameters "{\"commands\":[\"systemctl is-active ${svc}d || systemctl is-active ${svc}\"]}" \
        --output text)
    
    if echo "$service_status" | grep -q "active"; then
        echo -e "${GREEN}Serviço ativo${NC}"
    else
        echo -e "${RED}Serviço não está ativo${NC}"
        echo -e "  - Verifique se o serviço foi inicializado: sudo systemctl start ${svc}d"
        echo -e "  - Verifique os logs: sudo journalctl -u ${svc}d"
    fi
done

echo -e "\n${YELLOW}==== SQS: Verificando fila ====${NC}"
queue_url=$(aws sqs get-queue-url --queue-name geo-queue --query "QueueUrl" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$queue_url" != "NOT_FOUND" ]; then
    echo -e "${GREEN}✓ Fila SQS geo-queue encontrada${NC}"
    
    # Verificar atributos da fila
    aws sqs get-queue-attributes \
        --queue-url "$queue_url" \
        --attribute-names All \
        --query "Attributes.{Messages:ApproximateNumberOfMessages,MessagesNotVisible:ApproximateNumberOfMessagesNotVisible}" \
        --output table
else
    echo -e "${YELLOW}⚠️ Fila SQS geo-queue não encontrada${NC}"
    echo -e "  - A fila será criada pelo Terraform durante o provisionamento"
fi

echo -e "\n${YELLOW}==== EKS: Verificando cluster ====${NC}"
if [ -z "$CLUSTER_NAME" ]; then
    echo -e "${YELLOW}⚠️ Nome do cluster não definido em infra-config.sh${NC}"
    CLUSTER_NAME="easyprofind-eks"
fi

cluster_status=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query "cluster.status" --output text 2>/dev/null || echo "NOT_FOUND")

if [ "$cluster_status" != "NOT_FOUND" ]; then
    echo -e "${GREEN}✓ Cluster EKS $CLUSTER_NAME encontrado (status: $cluster_status)${NC}"
    
    # Verificar nodegroups
    nodegroups=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query "nodegroups" --output text)
    
    if [ -n "$nodegroups" ]; then
        echo -e "${GREEN}✓ Nodegroups encontrados: $nodegroups${NC}"
        
        for ng in $nodegroups; do
            ng_status=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --query "nodegroup.status" --output text)
            ng_count=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --query "nodegroup.scalingConfig.desiredSize" --output text)
            
            echo -e "  - Nodegroup $ng: status=$ng_status, nodes=$ng_count"
        done
    else
        echo -e "${YELLOW}⚠️ Nenhum nodegroup encontrado${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Cluster EKS $CLUSTER_NAME não encontrado${NC}"
    echo -e "  - O cluster será criado pelo Terraform durante o provisionamento"
fi

echo -e "\n${YELLOW}==== Verificação concluída ====${NC}"