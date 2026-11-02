output "dashboard_name" {
  description = "Nome do dashboard no CloudWatch"
  value       = aws_cloudwatch_dashboard.this.dashboard_name
}

output "alarm_names" {
  description = "Nomes dos alarmes criados"
  value = concat(
    [for alarme in aws_cloudwatch_metric_alarm.lambda_erros : alarme.alarm_name],
    [aws_cloudwatch_metric_alarm.api_5xx.alarm_name, aws_cloudwatch_metric_alarm.dlq_com_mensagens.alarm_name],
  )
}
