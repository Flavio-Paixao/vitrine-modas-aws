# ==========================================
# Fase 4 (VTM-8): Eventos (EventBridge, SQS, SNS)
# ==========================================

variable "alert_email" {
  description = "E-mail que recebe os alertas de estoque baixo (opcional). Informe só na sua máquina, nunca no código."
  type        = string
  default     = null
}

variable "limite_estoque_baixo" {
  description = "Quantidade a partir da qual o estoque é considerado baixo"
  type        = number
  default     = 3
}

module "eventos" {
  source = "./modules/eventos"

  project_name          = var.project_name
  messaging_kms_key_arn = module.kms.messaging_key_arn
  alert_email           = var.alert_email
}

# ---------- publicador: stream do DynamoDB -> EventBridge ----------
data "aws_iam_policy_document" "publicador" {
  statement {
    sid     = "LerStreams"
    actions = ["dynamodb:DescribeStream", "dynamodb:GetRecords", "dynamodb:GetShardIterator", "dynamodb:ListStreams"]
    resources = [
      module.dynamodb.produtos_stream_arn,
      module.dynamodb.estoque_stream_arn,
      module.dynamodb.pedidos_stream_arn,
    ]
  }

  statement {
    sid       = "PublicarNoBarramento"
    actions   = ["events:PutEvents"]
    resources = [module.eventos.event_bus_arn]
  }

  statement {
    sid       = "UsarChaveDoDynamoDB"
    actions   = local.kms_actions
    resources = [module.kms.dynamodb_key_arn]
  }
}

module "fn_publicador" {
  source = "./modules/lambda_function"

  function_name = "${var.project_name}-publicador"
  source_dir    = "${local.lambdas_dir}/publicador"
  policy_json   = data.aws_iam_policy_document.publicador.json

  environment = {
    NOME_BARRAMENTO      = module.eventos.event_bus_name
    TABELA_PRODUTOS      = module.dynamodb.produtos_table_name
    TABELA_ESTOQUE       = module.dynamodb.estoque_table_name
    TABELA_PEDIDOS       = module.dynamodb.pedidos_table_name
    LIMITE_ESTOQUE_BAIXO = tostring(var.limite_estoque_baixo)
  }
}

# Um mapeamento por stream. Falha repetida divide o lote ao meio e, no fim, descarta (DECISIONS 7.3)
resource "aws_lambda_event_source_mapping" "stream" {
  for_each = {
    produtos = module.dynamodb.produtos_stream_arn
    estoque  = module.dynamodb.estoque_stream_arn
    pedidos  = module.dynamodb.pedidos_stream_arn
  }

  event_source_arn                   = each.value
  function_name                      = module.fn_publicador.function_arn
  starting_position                  = "LATEST"
  batch_size                         = 10
  maximum_retry_attempts             = 3
  bisect_batch_on_function_error     = true
  maximum_batching_window_in_seconds = 1
}

# ---------- processador: fila de pedidos -> confirma o pedido ----------
data "aws_iam_policy_document" "processador" {
  statement {
    sid       = "LerFila"
    actions   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
    resources = [module.eventos.pedidos_queue_arn]
  }

  statement {
    sid       = "ConfirmarPedido"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.dynamodb.pedidos_table_arn]
  }

  statement {
    sid       = "UsarChaveDoDynamoDB"
    actions   = local.kms_actions
    resources = [module.kms.dynamodb_key_arn]
  }
}

module "fn_processador" {
  source = "./modules/lambda_function"

  function_name = "${var.project_name}-processador"
  source_dir    = "${local.lambdas_dir}/processador"
  policy_json   = data.aws_iam_policy_document.processador.json

  environment = {
    TABELA_PEDIDOS = module.dynamodb.pedidos_table_name
  }
}

resource "aws_lambda_event_source_mapping" "fila_pedidos" {
  event_source_arn        = module.eventos.pedidos_queue_arn
  function_name           = module.fn_processador.function_arn
  batch_size              = 10
  function_response_types = ["ReportBatchItemFailures"]

  scaling_config {
    maximum_concurrency = 5
  }
}
