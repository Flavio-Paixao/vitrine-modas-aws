# ==========================================
# DATA SOURCES (conta e região, para montar ARNs e condições exatas)
# ==========================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  account_root = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  region       = data.aws_region.current.name
}

# ==========================================
# KEY POLICY DE MÍNIMO PRIVILÉGIO (adaptada do Seguros Horizonte)
# ==========================================
# Separa QUEM ADMINISTRA de QUEM USA a chave:
#
# 1) Administração: a conta (via IAM) gerencia a chave, mas NÃO criptografa/descriptografa.
# 2) Uso: criptografar/descriptografar só vale quando a chamada passa pelo serviço
#    certo (kms:ViaService) e vem desta conta (kms:CallerAccount).
#    Chave do DynamoDB -> só via DynamoDB. Chave do S3 -> só via S3.

locals {
  key_admin_actions = [
    "kms:CreateAlias", # não "kms:Create*": isso incluiria CreateGrant sem as condições abaixo
    "kms:Describe*",
    "kms:Enable*",
    "kms:List*",
    "kms:Put*",
    "kms:Update*",
    "kms:Revoke*",
    "kms:Disable*",
    "kms:Get*",
    "kms:Delete*",
    "kms:TagResource",
    "kms:UntagResource",
    "kms:ScheduleKeyDeletion",
    "kms:CancelKeyDeletion",
  ]

  key_usage_actions = [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:DescribeKey",
  ]
}

data "aws_iam_policy_document" "dynamodb_key" {
  #checkov:skip=CKV_AWS_111:Key policy: Resource * significa esta chave; restricao vem dos principals e conditions (DECISIONS 2.4)
  #checkov:skip=CKV_AWS_356:Key policy: Resource * significa esta chave (DECISIONS 2.4)
  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = local.key_admin_actions
    resources = ["*"] # numa key policy, "*" significa "esta chave"

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  statement {
    sid       = "UseOnlyThroughDynamoDB"
    effect    = "Allow"
    actions   = local.key_usage_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }

  # O DynamoDB cria "grants" para usar a chave em segundo plano.
  # Só permitimos grant quando é para um recurso da AWS, nunca para uma pessoa.
  statement {
    sid       = "AllowDynamoDBGrants"
    effect    = "Allow"
    actions   = ["kms:CreateGrant", "kms:ListGrants", "kms:RevokeGrant"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["dynamodb.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

data "aws_iam_policy_document" "s3_key" {
  #checkov:skip=CKV_AWS_111:Key policy: Resource * significa esta chave; restricao vem dos principals e conditions (DECISIONS 2.4)
  #checkov:skip=CKV_AWS_356:Key policy: Resource * significa esta chave (DECISIONS 2.4)
  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = local.key_admin_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  statement {
    sid       = "UseOnlyThroughS3"
    effect    = "Allow"
    actions   = local.key_usage_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["s3.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }
}

data "aws_iam_policy_document" "messaging_key" {
  #checkov:skip=CKV_AWS_111:Key policy: Resource * significa esta chave; restricao vem dos principals e conditions (DECISIONS 2.4)
  #checkov:skip=CKV_AWS_356:Key policy: Resource * significa esta chave (DECISIONS 2.4)
  statement {
    sid       = "KeyAdministration"
    effect    = "Allow"
    actions   = local.key_admin_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }
  }

  statement {
    sid       = "UseOnlyThroughSNS"
    effect    = "Allow"
    actions   = local.key_usage_actions
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = [local.account_root]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sns.${local.region}.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }

  # Serviços da AWS que PUBLICAM no tópico cifrado (EventBridge, alarmes do CloudWatch e
  # AWS Budgets) precisam gerar chave de dados. Só valem para chamadas desta conta (DECISIONS 7.4).
  statement {
    sid       = "AllowServicesToPublish"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt"]
    resources = ["*"]

    principals {
      type = "Service"
      identifiers = [
        "events.amazonaws.com",
        "cloudwatch.amazonaws.com",
        "budgets.amazonaws.com",
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# ==========================================
# CHAVE DO DYNAMODB (usada na Fase 1)
# ==========================================
resource "aws_kms_key" "dynamodb" {
  description             = "Chave KMS das tabelas DynamoDB (${var.project_name})"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true # troca o material criptográfico todo ano, sozinha
  policy                  = data.aws_iam_policy_document.dynamodb_key.json

  tags = {
    Name = "${var.project_name}-dynamodb-key"
  }
}

# O alias é um "apelido" legível. Sem ele, você só enxerga um ID tipo 1234abcd-....
resource "aws_kms_alias" "dynamodb" {
  name          = "alias/${var.project_name}-dynamodb"
  target_key_id = aws_kms_key.dynamodb.key_id
}

# ==========================================
# CHAVE DO S3 (bucket de logs)
# ==========================================
# Chave separada da do DynamoDB: se uma vazar ou for desativada, a outra não é afetada.
resource "aws_kms_key" "s3" {
  description             = "Chave KMS do bucket de logs S3 (${var.project_name})"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.s3_key.json

  tags = {
    Name = "${var.project_name}-s3-key"
  }
}

resource "aws_kms_alias" "s3" {
  name          = "alias/${var.project_name}-s3"
  target_key_id = aws_kms_key.s3.key_id
}

# ==========================================
# CHAVE DA MENSAGERIA (tópico SNS, Fase 4)
# ==========================================
resource "aws_kms_key" "messaging" {
  description             = "Chave KMS do topico SNS de alertas (${var.project_name})"
  deletion_window_in_days = var.deletion_window_in_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.messaging_key.json

  tags = {
    Name = "${var.project_name}-messaging-key"
  }
}

resource "aws_kms_alias" "messaging" {
  name          = "alias/${var.project_name}-messaging"
  target_key_id = aws_kms_key.messaging.key_id
}
