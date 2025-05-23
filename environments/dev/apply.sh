#!/bin/bash
set -e

echo "Iniciando aplicação da infraestrutura para ambiente DEV em etapas..."

# Inicializar Terraform
echo "Inicializando Terraform..."
terraform init

# Importar bucket S3 existente
echo "Importando bucket S3 existente..."
./import-bucket.sh

# Etapa 1: Criar VPC e recursos de rede
echo "Etapa 1: Criando VPC e recursos de rede..."
terraform apply -target=module.vpc -auto-approve

# Etapa 2: Criar instâncias EC2 auxiliares
echo "Etapa 2: Criando instâncias EC2 auxiliares..."
terraform apply -target=module.ec2_aux -auto-approve

# Etapa 3: Criar cluster EKS
echo "Etapa 3: Criando cluster EKS..."
terraform apply -target=module.eks -auto-approve

# Etapa 4: Criar API Gateway
echo "Etapa 4: Criando API Gateway..."
terraform apply -target=module.gateway -auto-approve

# Etapa 5: Criar fila SQS
echo "Etapa 5: Criando fila SQS..."
terraform apply -target=module.messaging -auto-approve

# Etapa 6: Criar recursos de segurança
echo "Etapa 6: Criando recursos de segurança..."
terraform apply -target=module.security -auto-approve

# Etapa 7: Aplicar o restante dos recursos (exceto addons do EKS)
echo "Etapa 7: Aplicando o restante dos recursos..."
terraform apply -target=aws_s3_bucket_versioning.logs_versioning -auto-approve

# Aguardar recursos estarem prontos
echo "Aguardando recursos estarem prontos..."
sleep 30

# Executar configuração automática
echo "Iniciando configuração automática..."
chmod +x ../../scripts/setup/check_ssm_availability.sh
chmod +x ../../scripts/setup/configure_infra.sh
../../scripts/setup/configure_infra.sh

# Verificar se a configuração foi bem-sucedida
if [ $? -eq 0 ]; then
    echo "Infraestrutura e serviços configurados com sucesso!"
    
    echo "⚠️ NOTA IMPORTANTE: Os addons do EKS precisam ser instalados manualmente"
    echo "Execute o seguinte comando após a conclusão deste script:"
    echo "../../scripts/setup/install_eks_addons_from_ec2.sh"
    echo "✅ Processo de implantação da infraestrutura finalizado com sucesso!"
else
    echo "⚠️ Falha na configuração da infraestrutura. Verifique os logs para mais detalhes."
    exit 1
fi