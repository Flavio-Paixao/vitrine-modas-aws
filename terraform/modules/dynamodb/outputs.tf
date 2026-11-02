output "produtos_table_name" {
  description = "Nome da tabela de produtos"
  value       = aws_dynamodb_table.produtos.name
}

output "produtos_table_arn" {
  description = "ARN da tabela de produtos"
  value       = aws_dynamodb_table.produtos.arn
}

output "produtos_stream_arn" {
  description = "ARN do stream da tabela de produtos (usado na Fase 4)"
  value       = aws_dynamodb_table.produtos.stream_arn
}

output "estoque_table_name" {
  description = "Nome da tabela de estoque"
  value       = aws_dynamodb_table.estoque.name
}

output "estoque_table_arn" {
  description = "ARN da tabela de estoque"
  value       = aws_dynamodb_table.estoque.arn
}

output "estoque_stream_arn" {
  description = "ARN do stream da tabela de estoque (usado na Fase 4)"
  value       = aws_dynamodb_table.estoque.stream_arn
}

output "pedidos_table_name" {
  description = "Nome da tabela de pedidos"
  value       = aws_dynamodb_table.pedidos.name
}

output "pedidos_table_arn" {
  description = "ARN da tabela de pedidos"
  value       = aws_dynamodb_table.pedidos.arn
}
