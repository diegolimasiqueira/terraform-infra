#!/bin/bash
set -e

echo "Importando bucket S3 existente para o estado do Terraform..."

# Nome do bucket
BUCKET_NAME="easyprofind-logs"

# Verificar se o recurso já existe no estado do Terraform
echo "Verificando se o bucket já existe no estado do Terraform..."
if terraform state list | grep -q "aws_s3_bucket.logs"; then
    echo "Bucket já existe no estado do Terraform. Pulando importação."
else
    # Verificar se o bucket existe na AWS
    echo "Verificando se o bucket $BUCKET_NAME existe na AWS..."
    if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
        echo "Importando bucket $BUCKET_NAME para o estado do Terraform..."
        terraform import aws_s3_bucket.logs $BUCKET_NAME
        echo "Bucket importado com sucesso!"
    else
        echo "Bucket $BUCKET_NAME não existe na AWS, será criado pelo Terraform."
    fi
fi