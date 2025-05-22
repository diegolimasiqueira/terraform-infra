# Módulo API Gateway

Este módulo cria um API Gateway com domínio personalizado.

## Recursos criados

- API Gateway REST API
- Recursos e métodos do API Gateway
- Domínio personalizado
- Mapeamento de caminhos base

## Uso

```hcl
module "gateway" {
  source           = "../../modules/apigateway"
  domain_name      = "api.example.com"
  certificate_arn  = "arn:aws:acm:us-east-1:123456789012:certificate/abcdef"
  mappings         = {
    "service1" = "service1",
    "service2" = "service2"
  }
}
```

## Inputs

| Nome | Descrição | Tipo | Default | Obrigatório |
|------|-----------|------|---------|:----------:|
| domain_name | Nome de domínio personalizado para o API Gateway | `string` | n/a | sim |
| certificate_arn | ARN do certificado ACM para o domínio | `string` | n/a | sim |
| mappings | Mapeamentos de caminhos para o API Gateway | `map(string)` | n/a | sim |
| stage_name | Nome do estágio do API Gateway | `string` | `"dev"` | não |

## Outputs

| Nome | Descrição |
|------|-----------|
| api_id | ID do API Gateway |
| api_url | URL do API Gateway |
| domain_name | Nome de domínio personalizado configurado |