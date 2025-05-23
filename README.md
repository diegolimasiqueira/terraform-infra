# Infraestrutura EasyProFind

Este projeto contém a infraestrutura como código (IaC) para o ambiente EasyProFind, utilizando Terraform para gerenciar recursos na AWS.

## Estrutura do Projeto

```
.
├── environments/                # Ambientes separados
│   ├── dev/                     # Ambiente de desenvolvimento
│   │   ├── main.tf              # Configuração principal
│   │   ├── variables.tf         # Variáveis específicas do ambiente
│   │   ├── outputs.tf           # Outputs específicos do ambiente
│   │   ├── terraform.tfvars     # Valores das variáveis para dev
│   │   ├── backend.tf           # Configuração do backend para dev
│   │   ├── providers.tf         # Configuração dos providers
│   │   ├── versions.tf          # Versões dos providers
│   │   └── apply.sh             # Script para aplicar infraestrutura dev
│   ├── staging/                 # Ambiente de staging
│   └── prod/                    # Ambiente de produção
├── modules/                     # Módulos reutilizáveis
│   ├── apigateway/              # Módulo API Gateway
│   ├── ec2/                     # Módulo EC2
│   ├── eks/                     # Módulo EKS
│   ├── database/                # Módulo para bancos de dados
│   ├── messaging/               # Módulo para filas SQS
│   ├── monitoring/              # Módulo para monitoramento
│   └── security/                # Módulo para IAM, KMS, etc.
├── scripts/                     # Scripts organizados por função
│   ├── setup/                   # Scripts de configuração inicial
│   │   ├── check_ssm_availability.sh  # Verifica disponibilidade do SSM
│   │   ├── configure_infra.sh         # Configura serviços nas instâncias
│   │   ├── install_prometheus.sh      # Instala e configura o Prometheus
│   │   ├── install_eks_addons_from_ec2.sh # Instala addons do EKS
│   │   └── configure_nominatim.sh     # Configura o Nominatim (manual)
│   ├── operations/              # Scripts operacionais
│   │   ├── check_infra.sh             # Verifica status dos serviços
│   │   ├── check_all.sh               # Verificação completa da infraestrutura
│   │   ├── check_aws_resources.sh     # Lista recursos AWS
│   │   └── test_keycloak.sh           # Testa o Keycloak
│   └── utils/                   # Scripts utilitários
│       ├── ec2_utils.sh               # Funções para EC2 e SSM
│       └── get_infra_data.sh          # Coleta dados da infraestrutura
├── backend.tf                   # Configuração do backend S3
├── versions.tf                  # Versões do Terraform e providers
└── README.md                    # Documentação
```

## Infraestrutura Provisionada

### 1. VPC (rede principal)
- Nome: `easyprofind-vpc`
- CIDR: `10.0.0.0/16`
- Subnets:
  - Públicas: `10.0.101.0/24`, `10.0.102.0/24`
  - Privadas: `10.0.1.0/24`, `10.0.2.0/24`
- Recursos: Internet Gateway, NAT Gateway, Route Tables

### 2. EKS (Kubernetes gerenciado)
- Nome: `easyprofind-eks`
- Versão: 1.32
- NodeGroup: t3.small, capacidade inicial de 1 nó
- AWS Load Balancer Controller instalado via Helm
- Ingress configurado para rotas: `/bff`, `/ms-geo`, `/ms-consumers`, `/ms-professionals`, `/ms-rates`

### 3. API Gateway
- Nome: `easyprofind-api`
- Domínio: `https://api.easyprofind.com`
- SSL: certificado ACM integrado
- Rotas configuradas para microserviços e instâncias EC2

### 4. Instâncias EC2 auxiliares

| Nome         | Tipo       | Disco | Elastic IP | Finalidade                         |
|--------------|------------|-------|------------|-------------------------------------|
| `keycloak`   | t3.micro   | 8 GB  | ✅          | Autenticação                        |
| `nominatim`  | t3.small   | 55 GB | ✅          | Geocodificação reversa              |
| `monitoring` | t3.micro   | 8 GB  | ✅          | Grafana, Prometheus, Loki           |
| `redis`      | t3.micro   | 8 GB  | ❌          | Cache interno                       |
| `postgres`   | t3.micro   | 8 GB  | ❌          | Banco de dados dos microserviços    |
| `mongodb`    | t3.micro   | 8 GB  | ❌          | Comentários, avaliações, etc.       |

### 5. SQS (fila para comunicação assíncrona)
- Nome da fila: `geo-queue`
- Permissões: `ms_bff` e `ms_geo` publicam e consomem

### 6. S3 (armazenamento)
- Bucket para estado do Terraform: `easyprofind-terraform-state`
- Bucket para logs do SSM: `easyprofind-logs`
- Tabela DynamoDB para lock do estado: `terraform-state-lock`

## Pré-requisitos

- Terraform >= 1.3.0
- AWS CLI configurado
- kubectl instalado
- Helm instalado
- jq instalado
- Acesso à AWS com permissões adequadas
- Domínio registrado no Route53
- Certificado SSL/TLS válido na ACM

## Configuração Inicial

### 1. Criar recursos para o backend remoto

Execute o script de configuração do backend que criará o bucket S3 e a tabela DynamoDB necessários:

```bash
# Tornar o script executável (se necessário)
chmod +x scripts/setup/setup_backend.sh

# Executar o script
./scripts/setup/setup_backend.sh
```

O script verifica se os recursos já existem antes de tentar criá-los e configura:
- Bucket S3 `easyprofind-terraform-state` com versionamento e criptografia
- Tabela DynamoDB `terraform-state-lock` para controle de concorrência

### 2. Uso

```bash
# Configurar credenciais AWS
aws configure

# Inicializar e aplicar a infraestrutura (inclui configuração automática dos serviços básicos)
cd environments/dev
./apply.sh

# Instalar addons do EKS (após aplicar a infraestrutura)
../../scripts/setup/install_eks_addons_from_ec2.sh

# Verificar o status completo da infraestrutura
../../scripts/operations/check_all.sh

# Verificar recursos AWS
../../scripts/operations/check_aws_resources.sh

# Testar o Keycloak
../../scripts/operations/test_keycloak.sh

# Configurar Nominatim manualmente (opcional)
../../scripts/setup/configure_nominatim.sh
```

## Acesso aos Serviços

- **Keycloak**: https://<KEYCLOAK_IP>:8443/auth
- **Grafana**: http://<MONITORING_IP>:3000
- **API Gateway**: https://api.easyprofind.com

## Limpeza

Para remover a infraestrutura:

```bash
cd environments/dev
./destroy.sh
```

**Autor**: Diego Lima  
**Ambiente**: Desenvolvimento (AWS - `us-east-1`)