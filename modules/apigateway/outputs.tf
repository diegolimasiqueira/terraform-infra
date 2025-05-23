output "rest_api_id" {
  description = "ID da API Gateway REST API"
  value       = aws_api_gateway_rest_api.api.id
}

output "stage_name" {
  description = "Nome do stage da API Gateway"
  value       = aws_api_gateway_stage.stage.stage_name
}

output "api_url" {
  description = "URL da API Gateway"
  value       = "${aws_api_gateway_deployment.api.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_stage.stage.stage_name}"
}

output "domain_name" {
  description = "Nome de domínio personalizado da API Gateway"
  value       = aws_api_gateway_domain_name.custom.domain_name
}