resource "aws_api_gateway_rest_api" "api" {
  name = "easyprofind-api"
  tags = {
    Project     = "EasyProFind"
    Environment = "dev"
    Owner       = "diego"
  }

  endpoint_configuration {
    types = ["EDGE"]
  }
}

resource "aws_api_gateway_resource" "paths" {
  for_each = var.mappings
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "get" {
  for_each = aws_api_gateway_resource.paths
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = each.value.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "proxy" {
  for_each = aws_api_gateway_resource.paths
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = each.value.id
  http_method = aws_api_gateway_method.get[each.key].http_method

  integration_http_method = "ANY"
  type                    = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_method.get,
    aws_api_gateway_integration.proxy
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.stage_name
  deployment_id = aws_api_gateway_deployment.api.id

  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      deployment_id
    ]
  }
}

resource "aws_api_gateway_domain_name" "custom" {
  domain_name     = var.domain_name
  certificate_arn = var.certificate_arn

  endpoint_configuration {
    types = ["EDGE"]
  }
  # lifecycle {
  #   prevent_destroy = true
  # }
}

resource "aws_api_gateway_base_path_mapping" "mapping" {
  api_id      = aws_api_gateway_rest_api.api.id
  stage_name  = var.stage_name
  domain_name = aws_api_gateway_domain_name.custom.domain_name
  base_path   = "(none)"

  lifecycle {
    create_before_destroy = true
  }
}
