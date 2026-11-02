# ==========================================
# BUCKET 1: FRONT-END ESTÁTICO (servido pelo CloudFront na Fase 5)
# ==========================================

# bucket_prefix: o Terraform acrescenta um sufixo aleatório.
# (Nomes de bucket são únicos no mundo; um nome fixo poderia já estar em uso.)
resource "aws_s3_bucket" "frontend" {
  #checkov:skip=CKV_AWS_144:Sem replicacao entre regioes por custo (DECISIONS 3.6)
  #checkov:skip=CKV_AWS_18:Sem server access logging no S3 (DECISIONS 3.6)
  #checkov:skip=CKV2_AWS_62:Sem consumidor de eventos (DECISIONS 3.6)
  #checkov:skip=CKV_AWS_145:Front-end publico usa SSE-S3, nao KMS (DECISIONS 3.2)
  bucket_prefix = "${var.project_name}-frontend-"

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

# Bloqueio de acesso público (as 4 travas). O acesso virá só do CloudFront (OAC), na Fase 5.
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versionamento: permite voltar a um deploy anterior do front-end
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Criptografia em repouso com SSE-S3 (chave gerenciada pela AWS), de propósito (DECISIONS 3.2)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "apagar-versoes-antigas"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.frontend_noncurrent_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  # O ciclo de vida de versões precisa que o versionamento já exista
  depends_on = [aws_s3_bucket_versioning.frontend]
}

# ==========================================
# BUCKET 2: LOGS (sem versionamento)
# ==========================================

resource "aws_s3_bucket" "logs" {
  #checkov:skip=CKV_AWS_144:Sem replicacao entre regioes por custo (DECISIONS 3.6)
  #checkov:skip=CKV_AWS_18:Sem server access logging no S3 (DECISIONS 3.6)
  #checkov:skip=CKV2_AWS_62:Sem consumidor de eventos (DECISIONS 3.6)
  #checkov:skip=CKV_AWS_21:Logs sem versionamento de proposito (DECISIONS 3.3)
  bucket_prefix = "${var.project_name}-logs-"

  tags = {
    Name = "${var.project_name}-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.logs_kms_key_arn
    }
    bucket_key_enabled = true # reduz chamadas ao KMS (e o custo)
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "arquivar-e-apagar-logs"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ==========================================
# POLICY: NEGAR QUALQUER ACESSO SEM HTTPS (nos 2 buckets)
# ==========================================

locals {
  # Mapa "apelido => bucket". Usado pelo for_each abaixo para não repetir código.
  buckets = {
    frontend = aws_s3_bucket.frontend
    logs     = aws_s3_bucket.logs
  }
}

data "aws_iam_policy_document" "tls_only" {
  for_each = local.buckets

  statement {
    sid     = "NegarTrafegoSemTLS"
    effect  = "Deny"
    actions = ["s3:*"]

    resources = [
      each.value.arn,
      "${each.value.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

# Atenção (Fase 5): um bucket só tem UMA bucket policy. Quando o CloudFront precisar de acesso
# ao front-end, a policy dele deve ser combinada com esta (source_policy_documents), não criada à parte.
resource "aws_s3_bucket_policy" "tls_only" {
  for_each = local.buckets

  bucket = each.value.id
  policy = data.aws_iam_policy_document.tls_only[each.key].json

  # A policy só é aplicada depois do bloqueio de acesso público (evita conflito de ordem)
  depends_on = [
    aws_s3_bucket_public_access_block.frontend,
    aws_s3_bucket_public_access_block.logs,
  ]
}
