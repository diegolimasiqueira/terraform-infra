#!/bin/bash
set -e

echo "⚠️ AVISO: Este script está obsoleto e não deve ser usado."
echo "Para instalar os addons do EKS, use o script:"
echo "../../scripts/setup/install_eks_addons_from_ec2.sh"
echo ""
echo "O script apply-addons.sh não funciona corretamente porque o cluster EKS"
echo "está em uma rede privada e não pode ser acessado diretamente."
echo "O script install_eks_addons_from_ec2.sh utiliza a instância EC2 de monitoring"
echo "como um 'bastion' para acessar o cluster e instalar os addons."
echo ""
echo "Saindo sem fazer alterações..."
exit 1