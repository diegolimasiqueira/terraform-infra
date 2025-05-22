#!/bin/bash
set -e

echo "⚠️ ATENÇÃO: Este script irá destruir toda a infraestrutura do ambiente DEV!"
echo "Isso inclui todas as instâncias EC2, EKS, API Gateway e outros recursos."
read -p "Tem certeza que deseja continuar? (digite 'sim' para confirmar): " confirmation

if [ "$confirmation" != "sim" ]; then
    echo "Operação cancelada."
    exit 0
fi

echo "Iniciando destruição da infraestrutura..."

# Verificar recursos antes da destruição
echo "Verificando recursos existentes..."
../../scripts/operations/check_aws_resources.sh

read -p "Continuar com a destruição? (digite 'sim' para confirmar): " final_confirmation

if [ "$final_confirmation" != "sim" ]; then
    echo "Operação cancelada."
    exit 0
fi

# Destruir infraestrutura
echo "Destruindo infraestrutura..."
terraform destroy -auto-approve

echo "Destruição concluída!"