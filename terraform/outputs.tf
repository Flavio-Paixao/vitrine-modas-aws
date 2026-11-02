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
