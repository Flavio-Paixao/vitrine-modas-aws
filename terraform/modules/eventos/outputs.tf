output "event_bus_name" {
  description = "Nome do barramento de eventos"
  value       = aws_cloudwatch_event_bus.this.name
}

output "event_bus_arn" {
  description = "ARN do barramento de eventos"
  value       = aws_cloudwatch_event_bus.this.arn
}

output "pedidos_queue_arn" {
  description = "ARN da fila de pedidos"
  value       = aws_sqs_queue.pedidos.arn
}

output "pedidos_dlq_arn" {
  description = "ARN da DLQ de pedidos"
  value       = aws_sqs_queue.pedidos_dlq.arn
}

output "pedidos_dlq_name" {
  description = "Nome da DLQ de pedidos (usado pelo alarme da Fase 6)"
  value       = aws_sqs_queue.pedidos_dlq.name
}

output "alertas_topic_arn" {
  description = "ARN do tópico de alertas"
  value       = aws_sns_topic.alertas.arn
}

output "pedidos_queue_name" {
  description = "Nome da fila de pedidos (usado pelo dashboard da Fase 6)"
  value       = aws_sqs_queue.pedidos.name
}
