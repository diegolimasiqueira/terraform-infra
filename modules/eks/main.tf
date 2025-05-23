module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  version         = "20.8.4"
  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  subnet_ids      = var.subnet_ids
  vpc_id          = var.vpc_id
  enable_irsa     = var.enable_irsa

  # Configurar acesso ao cluster para o usuário atual
  create_kms_key = true
  kms_key_administrators = [
    data.aws_caller_identity.current.arn
  ]
  
  # Permitir que o usuário atual acesse o cluster
  access_entries = {
    current_user = {
      kubernetes_groups = []
      principal_arn     = data.aws_caller_identity.current.arn
      
      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    aws-ebs-csi-driver = { most_recent = true }
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = [var.node_instance_type]
      desired_size   = var.desired_capacity
      min_size       = 1
      max_size       = 5
    }
  }

  tags = {
    Project     = "EasyProFind"
    Environment = "dev"
    Owner       = "diego"
  }
}