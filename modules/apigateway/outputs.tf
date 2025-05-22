output "api_id" {
  description = "ID do API Gateway"
  value       = aws_api_gateway_rest_api.api.id
}

output "api_url" {
  description = "URL do API Gateway"
  value       = "${aws_api_gateway_deployment.api.invoke_url}${aws_api_gateway_stage.stage.stage_name}"
}

output "domain_name" {
  description = "Nome de domínio personalizado configurado"
  value       = aws_api_gateway_domain_name.custom.domain_name
}