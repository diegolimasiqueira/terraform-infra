#!/bin/bash
set -e

echo "Este script configura o Nominatim manualmente."
echo "Execute este script separadamente após a configuração principal da infraestrutura."

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

# Obter ID da instância Nominatim
nominatim_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=nominatim" \
    --query "Reservations[].Instances[].InstanceId" \
    --output text)

if [ -z "$nominatim_id" ]; then
    echo "❌ Instância Nominatim não encontrada"
    exit 1
fi

# Verificar se o diretório já existe
echo "Verificando se o diretório Nominatim já existe..."
check_cmd="[ -d /srv/nominatim ] && echo 'exists' || echo 'not exists'"
command_id=$(execute_on_instance "$nominatim_id" "$check_cmd")
dir_exists=$(aws ssm get-command-invocation \
    --command-id "$command_id" \
    --instance-id "$nominatim_id" \
    --query "StandardOutputContent" \
    --output text 2>/dev/null || echo "not exists")

if [[ "$dir_exists" == *"exists"* ]]; then
    echo "✅ Diretório Nominatim já existe"
else
    echo "Criando diretório Nominatim..."
    mkdir_cmd="sudo mkdir -p /srv/nominatim && sudo chown ubuntu:ubuntu /srv/nominatim"
    command_id=$(execute_on_instance "$nominatim_id" "$mkdir_cmd")
    wait_for_command "$command_id" "$nominatim_id" "true"
fi

echo "✅ Configuração básica do Nominatim concluída"
echo "Para configuração completa, consulte a documentação do Nominatim."
exit 0