# Módulo EKS

Este módulo cria um cluster EKS (Elastic Kubernetes Service) na AWS.

## Recursos criados

- Cluster EKS
- Grupos de nós gerenciados
- IAM roles e políticas necessárias
- Add-ons do EKS (aws-ebs-csi-driver, coredns, kube-proxy, vpc-cni)

## Uso

```hcl
module "eks" {
  source             = "../../modules/eks"
  cluster_name       = "meu-cluster"
  cluster_version    = "1.29"
  node_instance_type = "t3.small"
  desired_capacity   = 3
}
```

## Inputs

| Nome | Descrição | Tipo | Default | Obrigatório |
|------|-----------|------|---------|:----------:|
| cluster_name | Nome do cluster EKS | `string` | n/a | sim |
| cluster_version | Versão do Kubernetes para o cluster EKS | `string` | `"1.29"` | não |
| node_instance_type | Tipo de instância para os nós do EKS | `string` | n/a | sim |
| desired_capacity | Número desejado de nós no cluster EKS | `number` | n/a | sim |
| enable_irsa | Habilitar IRSA (IAM Roles for Service Accounts) | `bool` | `true` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| cluster_name | Nome do cluster EKS |
| cluster_endpoint | Endpoint do cluster EKS |
| cluster_certificate_authority_data | Dados do certificado da autoridade do cluster |
| vpc_id | ID da VPC onde o cluster está implantado |
| private_subnets | IDs das subnets privadas |