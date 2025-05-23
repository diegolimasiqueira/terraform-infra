# Módulo EKS - EasyProFind

Este módulo cria um cluster EKS com todas as configurações necessárias para o projeto EasyProFind.

## Recursos criados

- Cluster EKS com versão configurável
- Node Group gerenciado com instâncias configuráveis
- Addons do EKS (aws-ebs-csi-driver, coredns, kube-proxy, vpc-cni)
- Configuração de acesso para o usuário atual
- ALB Ingress Controller via Helm
- Ingress para os microserviços

## Configuração de acesso

O módulo configura automaticamente o acesso ao cluster para o usuário atual que está executando o Terraform. Isso é feito através de:

1. Configuração de `access_entries` no módulo EKS
2. Política de acesso de administrador para o usuário atual
3. Criação de chave KMS com o usuário atual como administrador

## ALB Ingress Controller

O ALB Ingress Controller é instalado via Helm após o cluster estar pronto. O módulo:

1. Verifica se o cluster está ativo antes de instalar
2. Configura o controller para usar o nome do cluster correto
3. Cria uma conta de serviço para o controller
4. Configura um timeout adequado para a instalação

## Ingress para microserviços

O módulo cria um Ingress para os microserviços com:

1. Configuração para usar o ALB Ingress Controller
2. Rotas para os microserviços configurados
3. Configurações de health check e balanceamento de carga

## Dependências

O módulo depende de:

1. VPC com subnets privadas para o cluster
2. Políticas IAM para o ALB Ingress Controller

## Uso

```hcl
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "easyprofind-dev-cluster"
  cluster_version    = "1.32"
  node_instance_type = "t3.small"
  desired_capacity   = 1
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnets
}
```