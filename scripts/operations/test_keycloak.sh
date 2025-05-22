#!/bin/bash
set -e

echo "Testando instalação do Keycloak..."

# Obter ID da instância Keycloak
KEYCLOAK_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=keycloak" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

echo "Instância Keycloak: $KEYCLOAK_ID"

# Enviar comando simples para verificar o Keycloak
echo "Verificando se o Keycloak já está instalado..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$KEYCLOAK_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["ls -la /home/ubuntu/keycloak-22.0.5/bin/kc.sh 2>/dev/null || echo \"kc.sh não encontrado\""]}' \
    --query "Command.CommandId" \
    --output text)

echo "Comando enviado com ID: $COMMAND_ID"

# Aguardar comando concluir
echo "Aguardando conclusão do comando..."
sleep 5

# Verificar resultado
echo "Verificando resultado do comando..."
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$KEYCLOAK_ID"

# Verificar se o Keycloak está rodando
echo "Verificando se o Keycloak está rodando..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$KEYCLOAK_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["ps aux | grep -v grep | grep -E \"keycloak|kc.sh\" > /dev/null && echo \"Keycloak está rodando\" || echo \"Keycloak não está rodando\""]}' \
    --query "Command.CommandId" \
    --output text)

echo "Comando enviado com ID: $COMMAND_ID"

# Aguardar comando concluir
echo "Aguardando conclusão do comando..."
sleep 5

# Verificar resultado
echo "Verificando resultado do comando..."
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$KEYCLOAK_ID"

# Verificar se a porta 8443 está aberta
echo "Verificando se a porta 8443 está aberta..."
COMMAND_ID=$(aws ssm send-command \
    --instance-ids "$KEYCLOAK_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters '{"commands":["ss -tuln | grep 8443 || echo \"Porta 8443 não está aberta\""]}' \
    --query "Command.CommandId" \
    --output text)

echo "Comando enviado com ID: $COMMAND_ID"

# Aguardar comando concluir
echo "Aguardando conclusão do comando..."
sleep 5

# Verificar resultado
echo "Verificando resultado do comando..."
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$KEYCLOAK_ID"

echo "Teste concluído!"