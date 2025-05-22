# Fluxo de Execução da Infraestrutura EasyProFind

Este documento explica o fluxo de execução do código de infraestrutura, desde o início do provisionamento até a configuração completa dos serviços.

## 1. Início do Provisionamento

O fluxo começa quando o usuário executa o script `apply.sh` em um dos ambientes:

```bash
cd environments/dev
./apply.sh
```

## 2. Inicialização do Terraform

O script `apply.sh` realiza as seguintes etapas:

1. **Inicializa o Terraform**:
   ```bash
   terraform init
   ```

2. **Importa recursos existentes** (se necessário):
   ```bash
   terraform import module.gateway.aws_api_gateway_domain_name.custom api.easyprofind.com
   ```

3. **Cria um plano de execução**:
   ```bash
   terraform plan -out=tfplan
   ```

4. **Aplica o plano**:
   ```bash
   terraform apply tfplan
   ```

## 3. Provisionamento dos Recursos AWS

O Terraform provisiona os recursos na seguinte ordem (conforme definido nos módulos):

1. **VPC e rede** (subnets, NAT, IGW)
2. **EC2s auxiliares** (com EIP para 3 instâncias)
3. **EKS com Node Group**
4. **Instalação do ALB Ingress Controller** (via Helm)
5. **Ingress para os microserviços no EKS**
6. **Criação do API Gateway com SSL e rotas**
7. **Fila SQS** com permissões para `bff` e `geo`
8. **Buckets S3** para estado do Terraform e logs

## 4. Verificação de Disponibilidade do SSM

Após o provisionamento dos recursos, o script `check_ssm_availability.sh` verifica se as instâncias EC2 estão prontas para receber comandos via SSM:

```bash
../../scripts/setup/check_ssm_availability.sh
```

Este script:
- Obtém os IDs das instâncias EC2
- Verifica se o agente SSM está online em cada instância
- Aguarda até que todas as instâncias estejam prontas

## 5. Configuração dos Serviços

O script `configure_infra.sh` configura os serviços nas instâncias EC2:

```bash
../../scripts/setup/configure_infra.sh
```

Este script utiliza funções do arquivo `ec2_utils.sh` para:

1. **Configurar Keycloak**:
   - Verifica se já está instalado
   - Instala OpenJDK 17
   - Baixa e extrai o Keycloak
   - Inicia o serviço na porta 8443

2. **Configurar Redis**:
   - Instala o Redis
   - Configura para aceitar conexões externas
   - Inicia o serviço

3. **Configurar MongoDB**:
   - Adiciona o repositório oficial
   - Instala o MongoDB
   - Inicia o serviço

4. **Configurar PostgreSQL**:
   - Instala o PostgreSQL
   - Configura para aceitar conexões externas
   - Inicia o serviço

5. **Configurar Monitoring**:
   - Instala Prometheus
   - Instala Grafana
   - Inicia os serviços

6. **Configurar API Gateway**:
   - Verifica o certificado SSL/TLS
   - Configura CORS
   - Configura rotas

## 6. Verificação da Infraestrutura

Após a configuração, o usuário pode verificar o status da infraestrutura:

```bash
../../scripts/operations/check_infra.sh
```

Este script verifica:
- Se o API Gateway está acessível
- Se os endpoints dos microserviços estão respondendo
- Se os serviços auxiliares (Keycloak, Redis, etc.) estão funcionando
- Se o cluster EKS está operacional
- Se a fila SQS foi criada corretamente

## 7. Fluxo de Dados

Uma vez que a infraestrutura está configurada, o fluxo de dados segue este padrão:

1. **Requisições do Cliente**:
   - O cliente acessa `https://api.easyprofind.com`
   - O API Gateway recebe a requisição

2. **Roteamento**:
   - Requisições para `/bff`, `/ms-geo`, etc. são encaminhadas para o ALB do EKS
   - Requisições para `/monitoring`, `/redis`, etc. são encaminhadas para as instâncias EC2

3. **Processamento**:
   - Os microserviços no EKS processam as requisições
   - Comunicação assíncrona ocorre via fila SQS
   - Dados são armazenados no PostgreSQL e MongoDB
   - Cache é gerenciado pelo Redis

4. **Autenticação**:
   - O Keycloak gerencia a autenticação e autorização
   - Tokens JWT são validados pelos microserviços

5. **Monitoramento**:
   - Prometheus coleta métricas
   - Grafana exibe dashboards de monitoramento
   - Logs são armazenados no bucket S3

## 8. Limpeza (Destruição)

Para remover a infraestrutura, o usuário executa:

```bash
cd environments/dev
./destroy.sh
```

Este script:
- Solicita confirmação do usuário
- Mostra os recursos que serão destruídos
- Executa `terraform destroy`