# Prompt para Continuação do Projeto Terraform EasyProFind

## Contexto do Projeto

Estou trabalhando em um projeto de infraestrutura como código (IaC) para o EasyProFind usando Terraform para gerenciar recursos na AWS. O projeto segue a arquitetura definida no documento `infraestrutura_easyprofind.md` e implementa uma infraestrutura completa incluindo VPC, EKS, EC2, API Gateway, SQS e outros serviços AWS.

## Estado Atual

Até agora, implementamos:

1. Estrutura modular do projeto Terraform com ambientes separados (dev, staging, prod)
2. Scripts de automação para aplicação da infraestrutura em etapas sequenciais
3. Configuração não interativa para instalação de serviços nas instâncias EC2
4. Mecanismo para importar recursos existentes (como buckets S3)
5. Instalação dos addons do EKS a partir da instância EC2 de monitoring
6. Script de verificação completa da infraestrutura (`check_all.sh`)

## Problemas Resolvidos

1. Corrigimos problemas de dependências circulares usando a abordagem de aplicação em etapas
2. Resolvemos o problema de prompts interativos durante a instalação de pacotes usando `DEBIAN_FRONTEND=noninteractive`
3. Implementamos verificação para recursos já existentes antes de tentar importá-los
4. Aumentamos o tamanho do disco da instância Redis de 4GB para 8GB para atender aos requisitos mínimos
5. Corrigimos a configuração do certificado ACM para o API Gateway
6. Resolvemos o problema de acesso ao cluster EKS em rede privada usando a instância EC2 de monitoring como "bastion"
7. Corrigimos erros no script `install_eks_addons_from_ec2.sh`:
   - Resolvemos o erro de sintaxe: `do: comando não encontrado` na linha 92
   - Corrigimos o erro `Error: Kubernetes cluster unreachable` atualizando a AWS CLI e regenerando o kubeconfig
   - Implementamos uma solução robusta para garantir a compatibilidade da apiVersion (v1beta1) no kubeconfig
8. Implementamos um script de verificação completa da infraestrutura (`check_all.sh`) que testa todos os componentes

## Histórico de Problemas e Soluções

### Problema 1: Erro de conexão com o cluster EKS
- **Sintoma**: `Error: Kubernetes cluster unreachable: Get "http://localhost:8080/version": dial tcp 127.0.0.1:8080: connect: connection refused`
- **Causa**: O kubeconfig estava usando uma apiVersion obsoleta (v1alpha1) incompatível com o kubectl moderno
- **Solução**: 
  1. Atualizar a AWS CLI para a versão mais recente
  2. Remover completamente o kubeconfig existente
  3. Gerar um novo kubeconfig com a apiVersion correta (v1beta1)
  4. Verificar e substituir manualmente a apiVersion se necessário

### Problema 2: Erro de sintaxe no script
- **Sintoma**: `do: comando não encontrado` na linha 92
- **Causa**: Problemas de escape de caracteres e citação em scripts bash
- **Solução**: Usar heredoc para definir scripts complexos e evitar problemas de escape

### Problema 3: Contexto do kubeconfig não definido
- **Sintoma**: `error: current-context is not set` e `error: no context exists with the name`
- **Causa**: O kubeconfig não estava sendo gerado corretamente ou o contexto não estava sendo definido
- **Solução**: Garantir que o kubeconfig seja gerado corretamente e verificar explicitamente se o contexto está definido

### Problema 4: Duplicação de código no script de verificação
- **Sintoma**: O script `check_all.sh` tinha seções duplicadas e era cortado no editor
- **Causa**: Erro de edição e problemas com a estrutura do script
- **Solução**: Reescrever o script com uma estrutura mais limpa e sem duplicações

## Próximos Passos

Precisamos:

1. Melhorar a documentação com diagramas de arquitetura
2. Implementar monitoramento e alertas para a infraestrutura
3. Configurar CI/CD para automatizar a aplicação da infraestrutura
4. Implementar backup e recuperação de desastres
5. Adicionar mais testes automatizados para verificar aspectos específicos da infraestrutura:
   - Verificação de rotas do Ingress para os microserviços
   - Verificação de permissões IAM para os serviços
   - Testes de carga para verificar a escalabilidade

## Instruções para Continuação

Para continuar o trabalho:

1. Leia os arquivos `README.md`, `FLUXO_EXECUCAO.md` e `infraestrutura_easyprofind.md` para entender a arquitetura e o fluxo de execução
2. Examine a estrutura do projeto e os módulos Terraform
3. Verifique os scripts de automação em `scripts/`
4. Entenda as modificações feitas para resolver os problemas mencionados acima
5. Continue com os próximos passos listados

## Arquivos Importantes

- `README.md`: Documentação principal do projeto
- `FLUXO_EXECUCAO.md`: Explicação detalhada do fluxo de execução
- `infraestrutura_easyprofind.md`: Especificação da arquitetura
- `environments/dev/apply.sh`: Script principal para aplicação da infraestrutura
- `scripts/utils/ec2_utils.sh`: Funções para configuração das instâncias EC2
- `scripts/setup/install_eks_addons_from_ec2.sh`: Script para instalar addons do EKS a partir da instância de monitoring
- `scripts/operations/check_all.sh`: Script para verificação completa da infraestrutura
- `modules/eks/`: Módulo para o cluster EKS

## Comandos Úteis

```bash
# Aplicar a infraestrutura
cd environments/dev
./apply.sh

# Instalar addons do EKS (após aplicar a infraestrutura)
../../scripts/setup/install_eks_addons_from_ec2.sh

# Verificação completa da infraestrutura
../../scripts/operations/check_all.sh

# Verificar recursos AWS
../../scripts/operations/check_aws_resources.sh

# Testar o Keycloak
../../scripts/operations/test_keycloak.sh
```

Por favor, analise todos os arquivos mencionados para entender completamente a infraestrutura, o que foi feito até agora, os erros que enfrentamos e como foram resolvidos, e continue o desenvolvimento a partir deste ponto.