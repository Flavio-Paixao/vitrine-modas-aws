# ==========================================
# CÓDIGO: empacota a pasta em um .zip (dentro de .terraform/, que o git ignora)
# ==========================================
data "archive_file" "zip" {
  type        = "zip"
  source_dir  = var.source_dir
  excludes    = ["__pycache__"]
  output_path = "${path.root}/.terraform/lambda-zips/${var.function_name}.zip"
}

# ==========================================
# LOGS: grupo criado pelo Terraform, com retenção definida
# ==========================================
resource "aws_cloudwatch_log_group" "this" {
  #checkov:skip=CKV_AWS_158:Logs sem KMS proprio por simplicidade (DECISIONS 6.3)
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.function_name}-logs"
  }
}

# ==========================================
# ROLE: uma por função, com trust policy só para o serviço Lambda
# ==========================================
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.function_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Name = "${var.function_name}-role"
  }
}

# Logs só no grupo desta função + as permissões específicas passadas por quem chama
data "aws_iam_policy_document" "permissions" {
  source_policy_documents = [var.policy_json]

  statement {
    sid       = "EscreverLogsDestaFuncao"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "${var.function_name}-permissions"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.permissions.json
}

# X-Ray: política gerenciada da AWS que permite enviar os traços
resource "aws_iam_role_policy_attachment" "xray" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# ==========================================
# FUNÇÃO
# ==========================================
resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_117:Sem VPC: a funcao so fala com servicos gerenciados (DECISIONS 6.3)
  #checkov:skip=CKV_AWS_116:Sem DLQ: invocacao sincrona pela API (DECISIONS 6.3)
  #checkov:skip=CKV_AWS_115:Sem concorrencia reservada, para nao limitar o pico (DECISIONS 6.3)
  #checkov:skip=CKV_AWS_173:Variaveis de ambiente sem segredos (DECISIONS 6.3)
  #checkov:skip=CKV_AWS_272:Sem assinatura de codigo no projeto de estudo (DECISIONS 6.3)
  function_name = var.function_name
  role          = aws_iam_role.this.arn
  runtime       = var.runtime
  handler       = var.handler
  architectures = ["arm64"]
  timeout       = var.timeout
  memory_size   = var.memory_size

  filename         = data.archive_file.zip.output_path
  source_code_hash = data.archive_file.zip.output_base64sha256

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = var.environment
  }

  depends_on = [
    aws_cloudwatch_log_group.this,
    aws_iam_role_policy.this,
  ]

  tags = {
    Name = var.function_name
  }
}
