#!/bin/bash
set -e

# Importar funções utilitárias
source "$(dirname "$0")/../utils/ec2_utils.sh"

echo "Instalando addons do EKS a partir da instância de monitoring..."

# Obter ID da instância de monitoring
echo "Obtendo ID da instância de monitoring..."
monitoring_id=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=monitoring" "Name=instance-state-name,Values=running" \
    --query "Reservations[].Instances[].InstanceId" --output text)

if [ -z "$monitoring_id" ]; then
    echo "❌ Instância de monitoring não encontrada ou não está em execução"
    exit 1
fi

echo "Instância de monitoring: $monitoring_id"

# Obter nome do cluster EKS diretamente da AWS
echo "Obtendo nome do cluster EKS..."
cluster_name=$(aws eks list-clusters --query "clusters[0]" --output text)

if [ -z "$cluster_name" ] || [ "$cluster_name" == "None" ]; then
    echo "❌ Não foi possível encontrar nenhum cluster EKS na AWS."
    exit 1
fi

echo "Nome do cluster EKS: $cluster_name"

# Verificar se o cluster está ativo
echo "Verificando se o cluster EKS está ativo..."
cluster_status=$(aws eks describe-cluster --name "$cluster_name" --query "cluster.status" --output text)
if [ "$cluster_status" != "ACTIVE" ]; then
    echo "❌ Cluster EKS não está ativo (status: $cluster_status)"
    exit 1
fi

echo "✅ Cluster EKS está ativo"

# Verificar permissão EKS no perfil da instância
echo "Verificando permissão EKS no perfil da instância..."
ROLE_NAME="ec2_ssm_role"
POLICY_ARN="arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
attached=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query "AttachedPolicies[?PolicyArn=='$POLICY_ARN']" --output text)
if [ -z "$attached" ]; then
  echo "Anexando política EKS ao perfil da instância..."
  aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn "$POLICY_ARN"
  echo "✅ Política anexada"
else
  echo "✅ Política já anexada"
fi

# Função para executar comando SSM e aguardar
run_on_monitoring() {
  local script="$1"
  cmd_id=$(execute_on_instance "$monitoring_id" "$script")
  wait_for_command "$cmd_id" "$monitoring_id" "true"
}

# Script de preparação: instalar ferramentas básicas
prep_script="set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq jq curl unzip gnupg
"

echo "✔️ Preparando instância de monitoring..."
run_on_monitoring "$prep_script"
echo "✔️ Instalação de dependências concluída"

# Definir addons_script via heredoc para evitar problemas de citação
read -r -d '' addons_script << 'SSM_SCRIPT'
set -e
export DEBIAN_FRONTEND=noninteractive

# Limpar credenciais estáticas
rm -rf ~/.aws

# Atualizar AWS CLI
echo "🔧 Atualizando AWS CLI..."
curl -s "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o awscliv2.zip
unzip -oq awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws
echo "✅ AWS CLI: $(aws --version)"

# Instalar kubectl
echo "🔧 Instalando kubectl..."
curl -sLO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
echo "✅ kubectl client version: $(kubectl version --client | head -n1)"

# Limpar kubeconfig anterior
echo "🧹 Limpando kubeconfig anterior..."
rm -f ~/.kube/config && mkdir -p ~/.kube

# Gerar novo kubeconfig
echo "🔐 Gerando kubeconfig..."
aws eks update-kubeconfig --region us-east-1 --name $cluster_name

# Ajustar apiVersion
if grep -q 'client.authentication.k8s.io/v1alpha1' ~/.kube/config; then
  sed -i 's#client.authentication.k8s.io/v1alpha1#client.authentication.k8s.io/v1beta1#g' ~/.kube/config
  echo "✅ apiVersion ajustada para v1beta1"
fi

# Testar conexão EKS
echo "🧪 Testando acesso ao cluster..."
if ! kubectl get nodes > /dev/null 2>&1; then
  echo "❌ Falha ao acessar cluster"
  kubectl config get-contexts
  exit 1
fi

echo "✅ Acesso validado ao cluster"

# Instalar Helm
echo "🔧 Instalando Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Instalar AWS Load Balancer Controller via Helm
helm repo add eks https://aws.github.io/eks-charts && helm repo update
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  --namespace kube-system --set clusterName=$cluster_name --set serviceAccount.create=true

echo "✅ Addons instalados com sucesso"
SSM_SCRIPT


echo "✔️ Iniciando instalação de addons no cluster $cluster_name"
run_on_monitoring "$addons_script"

echo "✅ Script concluído com sucesso!"
