#!/bin/bash
set -e

echo "Importando recursos existentes para o estado do Terraform..."

# Verificar se o bucket S3 de logs existe
BUCKET_NAME="${var.project_name}-logs"
echo "Verificando se o bucket $BUCKET_NAME existe..."
if aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    echo "Importando bucket $BUCKET_NAME para o estado do Terraform..."
    terraform import aws_s3_bucket.logs $BUCKET_NAME
else
    echo "Bucket $BUCKET_NAME não existe, será criado pelo Terraform."
fi

echo "Importação concluída!"