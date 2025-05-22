#!/bin/bash
set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Configurações
BUCKET_NAME="easyprofind-terraform-state"
DYNAMODB_TABLE="terraform-state-lock"
REGION="us-east-1"

echo -e "${YELLOW}Configurando backend remoto do Terraform...${NC}"

# Verificar se o bucket já existe
echo -e "Verificando se o bucket S3 ${BUCKET_NAME} existe..."
if aws s3api head-bucket --bucket ${BUCKET_NAME} 2>/dev/null; then
    echo -e "${GREEN}Bucket ${BUCKET_NAME} já existe.${NC}"
else
    echo -e "Criando bucket S3 ${BUCKET_NAME}..."
    aws s3api create-bucket --bucket ${BUCKET_NAME} --region ${REGION}
    
    # Habilitar versionamento no bucket
    echo -e "Habilitando versionamento no bucket..."
    aws s3api put-bucket-versioning --bucket ${BUCKET_NAME} --versioning-configuration Status=Enabled
    
    # Habilitar criptografia por padrão
    echo -e "Habilitando criptografia por padrão..."
    aws s3api put-bucket-encryption --bucket ${BUCKET_NAME} \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'
    
    echo -e "${GREEN}Bucket S3 ${BUCKET_NAME} criado com sucesso.${NC}"
fi

# Verificar se a tabela DynamoDB já existe
echo -e "Verificando se a tabela DynamoDB ${DYNAMODB_TABLE} existe..."
if aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} 2>/dev/null; then
    echo -e "${GREEN}Tabela DynamoDB ${DYNAMODB_TABLE} já existe.${NC}"
else
    echo -e "Criando tabela DynamoDB ${DYNAMODB_TABLE}..."
    aws dynamodb create-table \
        --table-name ${DYNAMODB_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region ${REGION}
    
    echo -e "${GREEN}Tabela DynamoDB ${DYNAMODB_TABLE} criada com sucesso.${NC}"
fi

echo -e "${GREEN}Backend remoto configurado com sucesso!${NC}"
echo -e "Agora você pode inicializar o Terraform com 'terraform init'."