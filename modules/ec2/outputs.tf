output "instances" {
  description = "Instâncias EC2 criadas"
  value = aws_instance.aux
}

output "security_group_id" {
  description = "ID do security group criado para as instâncias"
  value = aws_security_group.ec2_sg.id
}

output "elastic_ips" {
  description = "IPs elásticos associados às instâncias"
  value = aws_eip.service
}