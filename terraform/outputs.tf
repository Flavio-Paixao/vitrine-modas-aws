# ==========================================
# OUTPUTS DA RAIZ
# ==========================================

output "dynamodb_kms_key_arn" {
  description = "ARN da chave KMS das tabelas DynamoDB (usada na Fase 1)"
  value       = module.kms.dynamodb_key_arn
}

output "s3_kms_key_arn" {
  description = "ARN da chave KMS do bucket de logs"
  value       = module.kms.s3_key_arn
}

output "frontend_bucket_name" {
  description = "Nome do bucket do front-end"
  value       = module.storage.frontend_bucket_name
}

output "logs_bucket_name" {
  description = "Nome do bucket de logs"
  value       = module.storage.logs_bucket_name
}

output "produtos_table_name" {
  description = "Nome da tabela de produtos"
  value       = module.dynamodb.produtos_table_name
}

output "estoque_table_name" {
  description = "Nome da tabela de estoque"
  value       = module.dynamodb.estoque_table_name
}

output "pedidos_table_name" {
  description = "Nome da tabela de pedidos"
  value       = module.dynamodb.pedidos_table_name
}

output "cognito_user_pool_id" {
  description = "ID do user pool do Cognito"
  value       = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "ID do app client do front-end"
  value       = module.cognito.user_pool_client_id
}

output "api_invoke_url" {
  description = "URL base da API (stage incluído)"
  value       = module.api.invoke_url
}

output "alertas_topic_arn" {
  description = "ARN do tópico SNS de alertas"
  value       = module.eventos.alertas_topic_arn
}

output "site_url" {
  description = "Endereço do site (CloudFront)"
  value       = "https://${module.cloudfront.domain_name}"
}

output "dashboard_name" {
  description = "Dashboard do CloudWatch"
  value       = module.observabilidade.dashboard_name
}
