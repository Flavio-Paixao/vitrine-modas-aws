output "function_name" {
  description = "Nome da função"
  value       = aws_lambda_function.this.function_name
}

output "function_arn" {
  description = "ARN da função"
  value       = aws_lambda_function.this.arn
}

output "invoke_arn" {
  description = "ARN de invocação (usado pelo API Gateway)"
  value       = aws_lambda_function.this.invoke_arn
}

output "role_name" {
  description = "Nome da role da função"
  value       = aws_iam_role.this.name
}

output "role_arn" {
  description = "ARN da role da função"
  value       = aws_iam_role.this.arn
}

output "log_group_name" {
  description = "Nome do grupo de logs da função"
  value       = aws_cloudwatch_log_group.this.name
}
