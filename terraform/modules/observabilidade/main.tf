data "aws_region" "current" {}

# ==========================================
# ALARMES (todos avisam o tópico SNS de alertas)
# ==========================================

# Erros em qualquer função: um alarme por função
resource "aws_cloudwatch_metric_alarm" "lambda_erros" {
  for_each = var.lambda_function_names

  alarm_name          = "${var.project_name}-${each.key}-erros"
  alarm_description   = "A função ${each.value} registrou erros"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions          = { FunctionName = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]
}

# Erros 5xx devolvidos pela API
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project_name}-api-5xx"
  alarm_description   = "A API devolveu respostas 5xx"
  namespace           = "AWS/ApiGateway"
  metric_name         = "5XXError"
  dimensions          = { ApiName = var.api_name, Stage = var.api_stage_name }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]
}

# Qualquer mensagem na DLQ é um pedido que não foi processado
resource "aws_cloudwatch_metric_alarm" "dlq_com_mensagens" {
  alarm_name          = "${var.project_name}-dlq-pedidos"
  alarm_description   = "Há mensagens na DLQ de pedidos"
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = var.pedidos_dlq_name }
  statistic           = "Maximum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]
}

# ==========================================
# DASHBOARD
# ==========================================
locals {
  regiao = data.aws_region.current.name

  metricas_invocacoes = [for apelido, nome in var.lambda_function_names : ["AWS/Lambda", "Invocations", "FunctionName", nome]]
  metricas_erros      = [for apelido, nome in var.lambda_function_names : ["AWS/Lambda", "Errors", "FunctionName", nome]]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = "${var.project_name}-visao-geral"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title   = "Lambdas: invocações"
          region  = local.regiao
          view    = "timeSeries"
          stat    = "Sum"
          period  = 300
          metrics = local.metricas_invocacoes
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "Lambdas: erros"
          region  = local.regiao
          view    = "timeSeries"
          stat    = "Sum"
          period  = 300
          metrics = local.metricas_erros
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "API: requisições e erros"
          region = local.regiao
          view   = "timeSeries"
          stat   = "Sum"
          period = 300
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", var.api_name, "Stage", var.api_stage_name],
            ["AWS/ApiGateway", "4XXError", "ApiName", var.api_name, "Stage", var.api_stage_name],
            ["AWS/ApiGateway", "5XXError", "ApiName", var.api_name, "Stage", var.api_stage_name],
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "Filas de pedidos"
          region = local.regiao
          view   = "timeSeries"
          stat   = "Maximum"
          period = 300
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.pedidos_queue_name],
            ["AWS/SQS", "ApproximateNumberOfMessagesVisible", "QueueName", var.pedidos_dlq_name],
          ]
        }
      },
    ]
  })
}

# ==========================================
# ORÇAMENTO (AWS Budgets): avisa antes de estourar
# ==========================================
resource "aws_budgets_budget" "mensal" {
  name         = "${var.project_name}-mensal"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [var.alarm_topic_arn]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [var.alarm_topic_arn]
  }
}

# ==========================================
# X-RAY: regra de amostragem (quanto das requisições vira traço)
# ==========================================
resource "aws_xray_sampling_rule" "padrao" {
  rule_name      = "${var.project_name}-amostragem"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.xray_fixed_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_name   = "*"
  service_type   = "*"
  resource_arn   = "*"
}
