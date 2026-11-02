data "aws_caller_identity" "current" {}

# ==========================================
# BARRAMENTO DE EVENTOS (EventBridge)
# ==========================================
# Quem produz o evento não sabe quem consome: regras ligam eventos a destinos (DECISIONS 7.1)
resource "aws_cloudwatch_event_bus" "this" {
  name = "${var.project_name}-eventos"

  tags = {
    Name = "${var.project_name}-eventos"
  }
}

# ==========================================
# FILA DE PEDIDOS + DLQ (SQS)
# ==========================================
resource "aws_sqs_queue" "pedidos_dlq" {
  name                      = "${var.project_name}-pedidos-dlq"
  message_retention_seconds = 1209600 # 14 dias para investigar o que falhou
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${var.project_name}-pedidos-dlq"
  }
}

resource "aws_sqs_queue" "pedidos" {
  name                       = "${var.project_name}-pedidos-processar"
  visibility_timeout_seconds = var.queue_visibility_timeout
  message_retention_seconds  = 345600 # 4 dias
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.pedidos_dlq.arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name = "${var.project_name}-pedidos-processar"
  }
}

# ==========================================
# TÓPICO DE ALERTAS (SNS), cifrado com a chave da mensageria
# ==========================================
resource "aws_sns_topic" "alertas" {
  name              = "${var.project_name}-alertas"
  kms_master_key_id = var.messaging_kms_key_arn

  tags = {
    Name = "${var.project_name}-alertas"
  }
}

# Assinatura por e-mail só existe se um e-mail for informado (e ele nunca vai para o código)
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email == null ? 0 : 1

  topic_arn = aws_sns_topic.alertas.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# ==========================================
# REGRAS: evento -> destino
# ==========================================
resource "aws_cloudwatch_event_rule" "pedido_criado" {
  name           = "${var.project_name}-pedido-criado"
  description    = "PedidoCriado vai para a fila de processamento"
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source        = ["vitrine.pedidos"]
    "detail-type" = ["PedidoCriado"]
  })
}

resource "aws_cloudwatch_event_target" "pedido_criado_fila" {
  rule           = aws_cloudwatch_event_rule.pedido_criado.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id      = "fila-pedidos"
  arn            = aws_sqs_queue.pedidos.arn
}

resource "aws_cloudwatch_event_rule" "estoque_baixo" {
  name           = "${var.project_name}-estoque-baixo"
  description    = "EstoqueBaixo vai para o tópico de alertas"
  event_bus_name = aws_cloudwatch_event_bus.this.name

  event_pattern = jsonencode({
    source        = ["vitrine.estoque"]
    "detail-type" = ["EstoqueBaixo"]
  })
}

resource "aws_cloudwatch_event_target" "estoque_baixo_alerta" {
  rule           = aws_cloudwatch_event_rule.estoque_baixo.name
  event_bus_name = aws_cloudwatch_event_bus.this.name
  target_id      = "topico-alertas"
  arn            = aws_sns_topic.alertas.arn
}

# ==========================================
# PERMISSÕES DOS DESTINOS (quem pode escrever neles)
# ==========================================
data "aws_iam_policy_document" "fila_pedidos" {
  statement {
    sid       = "EventBridgeEnviaPedidos"
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.pedidos.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.pedido_criado.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "pedidos" {
  queue_url = aws_sqs_queue.pedidos.id
  policy    = data.aws_iam_policy_document.fila_pedidos.json
}

# Tópico: EventBridge (regra de estoque), alarmes do CloudWatch e AWS Budgets (Fase 6)
data "aws_iam_policy_document" "topico_alertas" {
  statement {
    sid       = "EventBridgePublicaAlertaDeEstoque"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alertas.arn]

    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_cloudwatch_event_rule.estoque_baixo.arn]
    }
  }

  statement {
    sid       = "AlarmesEOrcamentoPublicam"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.alertas.arn]

    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "budgets.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_sns_topic_policy" "alertas" {
  arn    = aws_sns_topic.alertas.arn
  policy = data.aws_iam_policy_document.topico_alertas.json
}
