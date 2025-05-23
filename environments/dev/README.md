# Ambiente de Desenvolvimento - EasyProFind

Este diretório contém a configuração Terraform para o ambiente de desenvolvimento do projeto EasyProFind.

## Problemas conhecidos e soluções

### 1. Acesso ao cluster EKS

O Terraform pode enfrentar problemas ao tentar acessar o cluster EKS imediatamente após sua criação. Isso ocorre porque:

1. O cluster EKS leva tempo para ficar totalmente operacional
2. As credenciais de acesso podem não estar imediatamente disponíveis
3. Os nós do cluster podem não estar prontos

Para resolver isso, adicionamos:

- Configuração de acesso explícita para o usuário atual no módulo EKS
- Verificação de prontidão do cluster antes de instalar o ALB Ingress Controller
- Timeout maior para recursos que dependem do cluster EKS

### 2. Certificado ACM

O erro `Invalid certificate ARN` pode ocorrer se o ARN do certificado no arquivo `terraform.tfvars` não for válido. Certifique-se de:

1. Usar um ARN de certificado válido na sua conta AWS
2. Verificar se o certificado está na mesma região que os outros recursos

### 3. Tamanho do disco para Redis

O tamanho mínimo do disco para a instância Redis é 8GB devido ao requisito do snapshot base.

## Aplicação da infraestrutura

O script `apply.sh` aplica a infraestrutura em etapas sequenciais:

1. VPC e recursos de rede
2. EC2s auxiliares
3. Cluster EKS
4. API Gateway
5. Fila SQS
6. Recursos de segurança
7. Restante dos recursos

Esta abordagem garante que os recursos sejam criados na ordem correta, evitando problemas de dependências circulares.