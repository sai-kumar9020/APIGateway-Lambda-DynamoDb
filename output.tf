output "api_gateway_url" {
  value = "https://${aws_api_gateway_rest_api.contact_api.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/contact"
  description = "Invoke URL for the API Gateway endpoint"
}

