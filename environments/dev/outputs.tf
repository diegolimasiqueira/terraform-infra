output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "IDs das subnets privadas"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "IDs das subnets públicas"
  value       = module.vpc.public_subnets
}

output "eks_cluster_name" {
  description = "Nome do cluster EKS"
  value       = module.eks.cluster_name
}

output "instance_ips" {
  description = "IPs das instâncias auxiliares"
  value = {
    for k, instance in module.ec2_aux.instances : k => {
      private_ip = instance.private_ip
      public_ip  = instance.public_ip
    }
  }
}