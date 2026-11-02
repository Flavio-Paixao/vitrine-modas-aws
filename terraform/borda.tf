# ==========================================
# Fase 5 (VTM-9): Borda (CloudFront + S3 + API)
# ==========================================

module "cloudfront" {
  source = "./modules/cloudfront"

  project_name                = var.project_name
  frontend_bucket_domain_name = module.storage.frontend_bucket_regional_domain_name
  api_domain_name             = module.api.domain_name
  api_stage_name              = module.api.stage_name
}

# Só ESTA distribuição pode ler o bucket (condição AWS:SourceArn). O bucket segue sem acesso público.
data "aws_iam_policy_document" "cloudfront_le_frontend" {
  statement {
    sid       = "CloudFrontLeOFrontend"
    actions   = ["s3:GetObject"]
    resources = ["${module.storage.frontend_bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

# Página inicial de demonstração
resource "aws_s3_object" "index" {
  bucket       = module.storage.frontend_bucket_name
  key          = "index.html"
  source       = "${path.root}/../frontend/index.html"
  etag         = filemd5("${path.root}/../frontend/index.html")
  content_type = "text/html; charset=utf-8"
}
