# Módulo EC2

Este módulo cria instâncias EC2 para serviços auxiliares.

## Recursos criados

- Instâncias EC2
- Security Groups
- IAM roles para SSM
- Elastic IPs para instâncias selecionadas

## Uso

```hcl
module "ec2_aux" {
  source     = "../../modules/ec2"
  instances  = {
    keycloak = {
      ami           = "ami-0fc5d935ebf8bc3bc"
      instance_type = "t3.small"
      name          = "keycloak"
    }
  }
  vpc_id     = module.vpc.vpc_id
  subnet_id  = module.vpc.private_subnets[0]
}
```

## Inputs

| Nome | Descrição | Tipo | Default | Obrigatório |
|------|-----------|------|---------|:----------:|
| instances | Mapa de instâncias a serem criadas | `map(object)` | n/a | sim |
| vpc_id | ID da VPC onde as instâncias serão criadas | `string` | n/a | sim |
| subnet_id | ID da subnet onde as instâncias serão criadas | `string` | n/a | sim |
| ssh_allowed_cidrs | CIDRs permitidos para acesso SSH | `list(string)` | `["200.181.123.18/32"]` | não |
| tags | Tags adicionais a serem aplicadas às instâncias | `map(string)` | `{}` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| instances | Mapa de instâncias criadas |
| security_group_id | ID do security group criado |