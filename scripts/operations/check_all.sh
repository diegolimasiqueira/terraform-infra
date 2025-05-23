#!/bin/bash
set -uo pipefail  # não aborta no primeiro erro, mas fecha em pipe failures

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Contadores
ERRORS=0
WARNINGS=0
SUCCESSES=0

# Funções de log
header() { echo -e "\n${BLUE}====== $1 ======${NC}"; }
check_status() {
  if [ "$1" -eq 0 ]; then
    echo -e "${GREEN}✓ $2${NC}"; ((SUCCESSES++));
  else
    echo -e "${RED}✗ $2${NC}"; ((ERRORS++));
  fi
}
warning() { echo -e "${YELLOW}⚠️ $1${NC}"; ((WARNINGS++)); }

# Verifica se comando existe
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "${RED}✗ Comando $1 não encontrado. Instale-o primeiro.${NC}"
    ((ERRORS++))
  else
    ((SUCCESSES++))
  fi
}

# Verifica recurso AWS
check_aws_resource() {
  local typ="$1" name="$2" cmd="$3"
  echo -n "Verificando $typ ($name): "
  if eval "$cmd" &> /dev/null; then
    echo -e "${GREEN}ok${NC}"; ((SUCCESSES++));
  else
    echo -e "${RED}não encontrado${NC}"; ((ERRORS++));
  fi
}

# Verifica endpoint HTTP
check_endpoint() {
  local name="$1" url="$2" exp="$3" timeout="${4:-5}"
  echo -n "Verificando endpoint $name: "
  local code
  code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout $timeout --max-time $timeout "$url" 2>/dev/null || echo "000")
  if [ "$code" = "$exp" ]; then
    echo -e "${GREEN}ok (status $code)${NC}"; ((SUCCESSES++));
  else
    echo -e "${YELLOW}atenção (status $code, esperado $exp)${NC}"; ((WARNINGS++));
  fi
}

# Verifica serviço via SSM
check_ec2_service() {
  local inst="$1" svc="$2" cmd="$3"
  echo -n "Verificando $inst ($svc): "
  local iid
  iid=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$inst" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" --output text)
  if [ -z "$iid" ]; then
    echo -e "${RED}instância não encontrada${NC}"; ((ERRORS++)); return;
  fi
  local out
  out=$(aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$iid" \
    --parameters "{\"commands\":[\"$cmd\"]}" \
    --output text 2>/dev/null)
  if echo "$out" | grep -q -e "Failed" -e "Error"; then
    echo -e "${RED}falhou${NC}"; ((ERRORS++));
  elif echo "$out" | grep -q -e "running" -e "active"; then
    echo -e "${GREEN}ok${NC}"; ((SUCCESSES++));
  else
    echo -e "${RED}falhou${NC}"; ((ERRORS++));
  fi
}

# Verifica addon EKS
check_eks_addon() {
  local addon="$1" ns="${2:-kube-system}"
  echo -n "Verificando addon EKS $addon: "
  local iid
  iid=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" \
    --query "Reservations[].Instances[].InstanceId" --output text)
  if [ -z "$iid" ]; then
    echo -e "${RED}monitoring não encontrada${NC}"; ((ERRORS++)); return;
  fi
  local out
  out=$(aws ssm send-command \
    --document-name "AWS-RunShellScript" \
    --instance-ids "$iid" \
    --parameters "{\"commands\":[\"kubectl get deployment -n $ns | grep $addon\"]}" \
    --output text 2>/dev/null)
  if echo "$out" | grep -q "$addon"; then
    echo -e "${GREEN}ok${NC}"; ((SUCCESSES++));
  else
    echo -e "${RED}não encontrado${NC}"; ((ERRORS++));
  fi
}

# 0. Pré-requisitos
header "VERIFICANDO PRÉ-REQUISITOS"
check_command aws; check_command jq; check_command curl

# Carregar config ou defaults
source infra-config.sh 2>/dev/null || { REGION="us-east-1"; CLUSTER_NAME="easyprofind-dev-cluster"; }

# 1. Rede
header "RECURSOS DE REDE"
check_aws_resource "VPC" easyprofind-vpc "aws ec2 describe-vpcs --filters 'Name=tag:Name,Values=easyprofind-vpc'"
check_aws_resource "Subnets públicas" public-* "aws ec2 describe-subnets --filters 'Name=tag:Name,Values=public-*'"
check_aws_resource "Subnets privadas" private-* "aws ec2 describe-subnets --filters 'Name=tag:Name,Values=private-*'"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=easyprofind-vpc" --query "Vpcs[0].VpcId" --output text || echo "")
if [ -n "$VPC_ID" ]; then
  check_aws_resource "Internet Gateway" igw-* "aws ec2 describe-internet-gateways --filters 'Name=attachment.vpc-id,Values=$VPC_ID'"
else
  echo -e "Internet Gateway: ${RED}VPC não encontrada${NC}"; ((ERRORS++));
fi
check_aws_resource "NAT Gateway" nat-* "aws ec2 describe-nat-gateways --filter 'Name=state,Values=available'"

# 2. Instâncias EC2
header "INSTÂNCIAS EC2"
for inst in keycloak nominatim monitoring redis postgres mongodb; do
  check_aws_resource "Instância" "$inst" "aws ec2 describe-instances --filters 'Name=tag:Name,Values=$inst' 'Name=instance-state-name,Values=running'"
done

# 3. Serviços
header "SERVIÇOS NAS INSTÂNCIAS"
check_ec2_service keycloak Keycloak "ps aux | grep -v grep | grep -E 'keycloak|kc.sh'"
check_ec2_service keycloak Porta_8443 "ss -tuln | grep 8443"
check_ec2_service redis Redis "systemctl is-active redis-server"
check_ec2_service redis Redis_PING "redis-cli ping"
check_ec2_service mongodb MongoDB "systemctl is-active mongod"
check_ec2_service postgres PostgreSQL "systemctl is-active postgresql"
check_ec2_service monitoring Grafana "systemctl is-active grafana-server"
check_ec2_service monitoring Prometheus "ps aux | grep -v grep | grep prometheus"

# 4. Cluster EKS
header "CLUSTER EKS"
check_aws_resource "Cluster EKS" "$CLUSTER_NAME" "aws eks describe-cluster --name $CLUSTER_NAME"
check_aws_resource "NodeGroups" "$CLUSTER_NAME-*" "aws eks list-nodegroups --cluster-name $CLUSTER_NAME"

# 5. Addons EKS
header "ADDONS EKS"
check_eks_addon aws-load-balancer-controller

# 5.1 Configuração EKS
header "CONFIGURAÇÃO EKS"
check_ec2_service monitoring Kubeconfig "test -f ~/.kube/config && echo active"
check_ec2_service monitoring "apiVersion v1beta1" "grep -q 'client.authentication.k8s.io/v1beta1' ~/.kube/config && echo active"
check_ec2_service monitoring "Acesso ao EKS" "kubectl get nodes > /dev/null && echo active"

# 6. API Gateway
header "API GATEWAY"
check_aws_resource "API Gateway" easyprofind-api "aws apigateway get-rest-apis --query 'items[?name==\"easyprofind-api\"].id'"
check_aws_resource "Domínio API" api.easyprofind.com "aws apigateway get-domain-names --query 'items[?domainName==\"api.easyprofind.com\"].domainName'"
check_aws_resource "Certificado ACM" "*.easyprofind.com" "aws acm list-certificates --query 'CertificateSummaryList[?DomainName==\"*.easyprofind.com\"||DomainName==\"api.easyprofind.com\"].CertificateArn'"

# 7. Ingress Controller
header "INGRESS CONTROLLER"
check_ec2_service monitoring "Ingress Controller" "kubectl get ingress -A > /dev/null && echo active"
for path in bff ms-geo ms-consumers ms-professionals ms-rates; do
  check_ec2_service monitoring "Rota /$path" "kubectl get ingress -A | grep $path && echo active"
done

# 8. SQS
header "SQS"
check_aws_resource "Fila SQS" geo-queue "aws sqs get-queue-url --queue-name geo-queue"

# 9. Permissões IAM
header "PERMISSÕES IAM"
check_aws_resource "Política EKS" AmazonEKSClusterPolicy "aws iam list-attached-role-policies --role-name ec2_ssm_role --query \"AttachedPolicies[?PolicyArn=='arn:aws:iam::aws:policy/AmazonEKSClusterPolicy'].PolicyArn\""

# 10. S3
header "S3"
check_aws_resource "Bucket Terraform" easyprofind-terraform-state "aws s3api head-bucket --bucket easyprofind-terraform-state"
check_aws_resource "Bucket Logs" easyprofind-logs "aws s3api head-bucket --bucket easyprofind-logs"

# 11. Endpoints
header "ENDPOINTS"
check_endpoint API_Gateway https://api.easyprofind.com/health 200
for svc in ms-consumers ms-professionals ms-geo bff; do
  check_endpoint $svc https://api.easyprofind.com/$svc/health 200

done

# Resumo
header "RESUMO"
echo -e "${GREEN}✓ Sucessos: $SUCCESSES${NC}"
echo -e "${YELLOW}⚠️ Avisos: $WARNINGS${NC}"
echo -e "${RED}✗ Erros: $ERRORS${NC}"

if [ $ERRORS -eq 0 ]; then
  echo -e "\n${GREEN}✅ Todos os testes foram concluídos com sucesso!${NC}"
  exit 0
else
  echo -e "\n${RED}❌ Alguns testes falharam. Verifique os erros acima.${NC}"
  exit 1
fi
