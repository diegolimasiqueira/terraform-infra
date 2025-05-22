variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "eks_cluster_name" {
  type    = string
  default = "easyprofind-prod-cluster"
}

variable "node_instance_type" {
  type    = string
  default = "t3.large"
}

variable "node_desired_capacity" {
  type    = number
  default = 3
}

variable "auxiliary_instances" {
  type = map(object({
    ami           = string
    instance_type = string
    name          = string
  }))
}

variable "api_domain" {
  type = string
}

variable "acm_certificate_arn" {
  type = string
}

variable "api_gateway_mappings" {
  type = map(string)
}

variable "key_name" { 
  type = string 
}