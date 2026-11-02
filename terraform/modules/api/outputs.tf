output "rest_api_id" {
  description = "ID da API"
  value       = aws_api_gateway_rest_api.this.id
}

output "execution_arn" {
  description = "ARN de execução da API"
  value       = aws_api_gateway_rest_api.this.execution_arn
}

output "stage_name" {
  description = "Nome do stage"
  value       = aws_api_gateway_stage.this.stage_name
}

output "invoke_url" {
  description = "URL base da API (stage incluído)"
  value       = aws_api_gateway_stage.this.invoke_url
}

output "domain_name" {
  description = "Domínio regional da API (usado como origem do CloudFront na Fase 5)"
  value       = "${aws_api_gateway_rest_api.this.id}.execute-api.${data.aws_region.current.name}.amazonaws.com"
}
