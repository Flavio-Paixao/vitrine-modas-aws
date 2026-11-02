output "user_pool_id" {
  description = "ID do user pool"
  value       = aws_cognito_user_pool.main.id
}

output "user_pool_arn" {
  description = "ARN do user pool (usado pelo authorizer da API na Fase 3)"
  value       = aws_cognito_user_pool.main.arn
}

output "user_pool_client_id" {
  description = "ID do app client do front-end"
  value       = aws_cognito_user_pool_client.web.id
}

output "issuer_url" {
  description = "URL do emissor dos tokens (issuer)"
  value       = "https://${aws_cognito_user_pool.main.endpoint}"
}
