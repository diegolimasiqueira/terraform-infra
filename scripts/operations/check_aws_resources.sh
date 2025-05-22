#!/bin/bash
# Script para verificar recursos AWS remanescentes
echo "=== Verificando instâncias EC2 ==="
aws ec2 describe-instances --query "Reservations[*].Instances[*].{ID:InstanceId,Name:Tags[?Key=='Name']|[0].Value,State:State.Name}" --output table

echo "=== Verificando VPCs ==="
aws ec2 describe-vpcs --query "Vpcs[*].{VpcId:VpcId,Name:Tags[?Key=='Name']|[0].Value,CIDR:CidrBlock,IsDefault:IsDefault}" --output table

echo "=== Verificando Security Groups ==="
aws ec2 describe-security-groups --query "SecurityGroups[?GroupName!='default'].{ID:GroupId,Name:GroupName,VPC:VpcId}" --output table

echo "=== Verificando Elastic IPs ==="
aws ec2 describe-addresses --query "Addresses[*].{IP:PublicIp,AllocationId:AllocationId,InstanceId:InstanceId}" --output table

echo "=== Verificando volumes EBS não anexados ==="
aws ec2 describe-volumes --query "Volumes[?State=='available'].{ID:VolumeId,Size:Size,Type:VolumeType}" --output table

echo "=== Verificando buckets S3 ==="
aws s3api list-buckets --query "Buckets[*].Name" --output table

echo "=== Verificando API Gateways ==="
aws apigateway get-rest-apis --query "items[*].{ID:id,Name:name}" --output table

echo "=== Verificando certificados ACM ==="
aws acm list-certificates --query "CertificateSummaryList[*].{ARN:CertificateArn,Domain:DomainName}" --output table

echo "=== Verificando IAM roles ==="
aws iam list-roles --query "Roles[?starts_with(RoleName, 'ec2_') || starts_with(RoleName, 'aws-')].RoleName" --output table

echo "=== Verificando registros Route53 ==="
aws route53 list-hosted-zones --query "HostedZones[*].{ID:Id,Name:Name,Private:Config.PrivateZone}" --output table

echo "=== Verificando clusters EKS ==="
aws eks list-clusters --query "clusters" --output table

echo "=== Verificando filas SQS ==="
aws sqs list-queues --query "QueueUrls" --output table