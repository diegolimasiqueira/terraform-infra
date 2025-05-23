diego@scarlet:~/Documentos/repos/terraform-infra/scripts/operations$ ./check_all.sh 

====== VERIFICANDO PRÉ-REQUISITOS ======

====== RECURSOS DE REDE ======
Verificando VPC (easyprofind-vpc): ok
Verificando Subnets públicas (public-*): ok
Verificando Subnets privadas (private-*): ok
Verificando Internet Gateway (igw-*): ok
Verificando NAT Gateway (nat-*): ok

====== INSTÂNCIAS EC2 ======
Verificando Instância (keycloak): ok
Verificando Instância (nominatim): ok
Verificando Instância (monitoring): ok
Verificando Instância (redis): ok
Verificando Instância (postgres): ok
Verificando Instância (mongodb): ok

====== SERVIÇOS NAS INSTÂNCIAS ======
Verificando keycloak (Keycloak): falhou
Verificando keycloak (Porta_8443): falhou
Verificando redis (Redis): ok
Verificando redis (Redis_PING): falhou
Verificando mongodb (MongoDB): ok
Verificando postgres (PostgreSQL): ok
Verificando monitoring (Grafana): ok
Verificando monitoring (Prometheus): falhou

====== CLUSTER EKS ======
Verificando Cluster EKS (easyprofind-dev-cluster): ok
Verificando NodeGroups (easyprofind-dev-cluster-*): ok

====== ADDONS EKS ======
Verificando addon EKS aws-load-balancer-controller: ok

====== CONFIGURAÇÃO EKS ======
Verificando monitoring (Kubeconfig): ok
Verificando monitoring (apiVersion v1beta1): ok
Verificando monitoring (Acesso ao EKS): ok

====== API GATEWAY ======
Verificando API Gateway (easyprofind-api): ok
Verificando Domínio API (api.easyprofind.com): ok
Verificando Certificado ACM (*.easyprofind.com): ok

====== INGRESS CONTROLLER ======
Verificando monitoring (Ingress Controller): ok
Verificando monitoring (Rota /bff): ok
Verificando monitoring (Rota /ms-geo): ok
Verificando monitoring (Rota /ms-consumers): ok
Verificando monitoring (Rota /ms-professionals): ok
Verificando monitoring (Rota /ms-rates): ok

====== SQS ======
Verificando Fila SQS (geo-queue): não encontrado

====== PERMISSÕES IAM ======
Verificando Política EKS (AmazonEKSClusterPolicy): ok

====== S3 ======
Verificando Bucket Terraform (easyprofind-terraform-state): ok
Verificando Bucket Logs (easyprofind-logs): ok

====== ENDPOINTS ======
Verificando endpoint API_Gateway: atenção (status 000000, esperado 200)
Verificando endpoint ms-consumers: atenção (status 000000, esperado 200)
Verificando endpoint ms-professionals: atenção (status 000000, esperado 200)
Verificando endpoint ms-geo: atenção (status 000000, esperado 200)
Verificando endpoint bff: atenção (status 000000, esperado 200)

====== RESUMO ======
✓ Sucessos: 36
⚠ Avisos: 5
✗ Erros: 5

❌ Alguns testes falharam. Verifique os erros acima.
diego@scarlet:~/Documentos/repos/terraform-infra/scripts/operations$ 
