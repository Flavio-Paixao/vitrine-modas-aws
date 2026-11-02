output "frontend_bucket_name" {
  description = "Nome do bucket do front-end"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN do bucket do front-end (usado na Fase 5 pelo CloudFront)"
  value       = aws_s3_bucket.frontend.arn
}

output "logs_bucket_name" {
  description = "Nome do bucket de logs"
  value       = aws_s3_bucket.logs.id
}

output "bucket_arns" {
  description = "ARNs dos 2 buckets (frontend e logs)"
  value = [
    aws_s3_bucket.frontend.arn,
    aws_s3_bucket.logs.arn,
  ]
}
