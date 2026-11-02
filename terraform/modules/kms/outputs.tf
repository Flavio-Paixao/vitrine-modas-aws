output "dynamodb_key_arn" {
  description = "ARN da chave KMS do DynamoDB"
  value       = aws_kms_key.dynamodb.arn
}

output "s3_key_arn" {
  description = "ARN da chave KMS do S3 (bucket de logs)"
  value       = aws_kms_key.s3.arn
}
