output "distribution_arn" {
  description = "ARN da distribuição (usado na policy do bucket)"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_id" {
  description = "ID da distribuição"
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "Endereço do site (xxxx.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}
