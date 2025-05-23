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

2. **Importa recursos existentes**:
   ```bash
   ./import-bucket.sh
   ```

3. **Aplica a infraestrutura em etapas sequenciais**:
   - Cria VPC e recursos de rede
   - Cria instâncias EC2 auxiliares
   - Cria cluster EKS
   - Cria API Gateway
   - Cria fila SQS
   - Cria recursos de segurança
   - Aplica o restante dos recursos

## 3. Verificação de Disponibilidade do SSM

Após o provisionamento dos recursos, o script `check_ssm_availability.sh` verifica se as instâncias EC2 estão prontas para receber comandos via SSM:

```bash
../../scripts/setup/check_ssm_availability.sh
```

Este script:
- Obtém os IDs das instâncias EC2
- Verifica se o agente SSM está online em cada instância
- Aguarda até que todas as instâncias estejam prontas

## 4. Configuração dos Serviços

O script `configure_infra.sh` configura os serviços nas instâncias EC2:

```bash
../../scripts/setup/configure_infra.sh
```

Este script utiliza funções do arquivo `ec2_utils.sh` para:

> **Nota**: Todos os comandos de instalação são configurados com `DEBIAN_FRONTEND=noninteractive` e opções adicionais para evitar prompts interativos durante a instalação de pacotes.

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
   - Instala Grafana
   - Configura e inicia o serviço

6. **Instalar Prometheus**:
   - Executa o script `install_prometheus.sh`
   - Instala o Prometheus via apt
   - Inicia e verifica o serviço

7. **Configurar API Gateway**:
   - Verifica o certificado SSL/TLS
   - Configura CORS
   - Configura rotas

8. **Verificar Status dos Serviços**:
   - Verifica se todos os serviços críticos estão funcionando
   - Tenta reiniciar serviços que não estão ativos
   - Retorna código de saída apropriado

## 5. Instalação dos Addons do EKS

Após a configuração dos serviços, o usuário deve executar o script `install_eks_addons_from_ec2.sh` para instalar os addons do EKS:

```bash
../../scripts/setup/install_eks_addons_from_ec2.sh
```

> **Nota**: Este script utiliza a instância EC2 de monitoring como um "bastion" para acessar o cluster EKS que está em uma rede privada.

Este script:
- Verifica se o cluster EKS está ativo
- Verifica e configura as permissões IAM necessárias
- Instala dependências básicas na instância de monitoring
- Atualiza a AWS CLI para a versão mais recente
- Instala kubectl v1.28.0
- Configura o kubeconfig com a apiVersion correta (v1beta1)
- Testa a conexão com o cluster EKS
- Instala Helm
- Instala o AWS Load Balancer Controller via Helm

## 6. Configuração do Nominatim (Manual)

A configuração do Nominatim é feita manualmente após a conclusão do fluxo principal:

```bash
../../scripts/setup/configure_nominatim.sh
```

Este script:
- Cria o diretório base para o Nominatim
- Configura permissões básicas

> **Nota**: A instalação completa do Nominatim é feita manualmente devido à sua complexidade e requisitos de tempo.

## 7. Fluxo de Execução

O fluxo de execução completo segue estas etapas:

1. **Provisionamento da infraestrutura** (apply.sh)
2. **Verificação do SSM** (check_ssm_availability.sh)
3. **Configuração dos serviços** (configure_infra.sh)
4. **Instalação do Prometheus** (install_prometheus.sh)
5. **Instalação dos addons do EKS** (install_eks_addons_from_ec2.sh)
6. **Configuração do Nominatim** (configure_nominatim.sh)
7. **Verificação da infraestrutura** (check_infra.sh ou check_all.sh)

As etapas 1-4 são executadas automaticamente pelo script `apply.sh`. As etapas 5-7 devem ser executadas manualmente pelo usuário após a conclusão do script `apply.sh`.

## 8. Verificação da Infraestrutura

Após a configuração, o usuário pode verificar o status da infraestrutura:

```bash
# Verificação básica
../../scripts/operations/check_infra.sh

# Verificação completa (inclui addons do EKS e todos os componentes)
../../scripts/operations/check_all.sh
```

O script `check_infra.sh` verifica:
- Se o API Gateway está acessível
- Se os endpoints dos microserviços estão respondendo
- Se os serviços auxiliares (Keycloak, Redis, etc.) estão funcionando
- Se o cluster EKS está operacional
- Se a fila SQS foi criada corretamente

O script `check_all.sh` realiza uma verificação mais abrangente:
- Todos os recursos de rede (VPC, subnets, gateways)
- Todas as instâncias EC2 e seus serviços
- Cluster EKS e seus nodegroups
- Addons do EKS (AWS Load Balancer Controller)
- API Gateway e seus endpoints
- Filas SQS
- Buckets S3
- Endpoints dos microserviços
- Fornece um resumo com contagem de sucessos, avisos e erros

## 9. Limpeza (Destruição)

Para remover a infraestrutura, o usuário executa:

```bash
cd environments/dev
./destroy.sh
```

Este script:
- Solicita confirmação do usuário
- Mostra os recursos que serão destruídos
- Executa `terraform destroy`