#!/bin/bash
set -e

echo "Iniciando aplicação da infraestrutura para ambiente DEV..."

# Inicializar Terraform
echo "Inicializando Terraform..."
terraform init

# Importar domínio do API Gateway se necessário
echo "Verificando domínio do API Gateway..."
if ! terraform state show module.gateway.aws_api_gateway_domain_name.custom &>/dev/null; then
    echo "Importando domínio do API Gateway..."
    terraform import module.gateway.aws_api_gateway_domain_name.custom api.easyprofind.com || true
fi

# Importar stage do API Gateway se necessário
echo "Verificando stage do API Gateway..."
if ! terraform state show module.gateway.aws_api_gateway_stage.stage &>/dev/null; then
    echo "Importando stage do API Gateway..."
    terraform import module.gateway.aws_api_gateway_stage.stage wz2w8yw591/dev || true
fi

# Criar plano
echo "Criando plano de execução..."
terraform plan -out=tfplan

# Aplicar plano
echo "Aplicando infraestrutura..."
terraform apply tfplan

# Aguardar recursos estarem prontos
echo "Aguardando recursos estarem prontos..."
sleep 30

# Executar configuração automática
echo "Iniciando configuração automática..."
chmod +x ../../scripts/setup/check_ssm_availability.sh
chmod +x ../../scripts/setup/configure_infra.sh
../../scripts/setup/configure_infra.sh

echo "Processo concluído!"