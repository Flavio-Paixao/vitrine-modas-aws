# ==========================================
# POLÍTICAS GERENCIADAS PELA AWS (buscadas pelo nome, sem copiar IDs)
# ==========================================
data "aws_cloudfront_cache_policy" "cache_otimizado" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "sem_cache" {
  name = "Managed-CachingDisabled"
}

# Repassa os cabeçalhos do cliente (inclusive Authorization) para a API, menos o Host
data "aws_cloudfront_origin_request_policy" "todos_menos_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "seguranca" {
  name = "Managed-SecurityHeadersPolicy"
}

# ==========================================
# OAC: o CloudFront assina as requisições ao S3 (o bucket continua privado)
# ==========================================
resource "aws_cloudfront_origin_access_control" "frontend" {
  name                              = "${var.project_name}-frontend"
  description                       = "Acesso do CloudFront ao bucket do front-end"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# ==========================================
# DISTRIBUIÇÃO: um domínio para o site (S3) e para a API (/api/*)
# ==========================================
resource "aws_cloudfront_distribution" "this" {
  #checkov:skip=CKV_AWS_174:Sem dominio proprio, o certificado padrao do CloudFront nao permite escolher o TLS minimo (DECISIONS 8.4)
  #checkov:skip=CKV_AWS_68:Sem WAF no projeto de estudo (DECISIONS 8.4)
  #checkov:skip=CKV2_AWS_47:Sem WAF no projeto de estudo (DECISIONS 8.4)
  #checkov:skip=CKV_AWS_86:Sem access log do CloudFront (DECISIONS 8.4)
  #checkov:skip=CKV_AWS_310:Sem origin failover: ha uma origem por caminho (DECISIONS 8.4)
  #checkov:skip=CKV_AWS_374:Sem restricao geografica: a loja atende qualquer visitante (DECISIONS 8.4)
  #checkov:skip=CKV2_AWS_42:Sem dominio proprio, usa o certificado padrao do CloudFront (DECISIONS 8.4)
  enabled             = true
  is_ipv6_enabled     = true
  http_version        = "http2and3"
  comment             = "${var.project_name}: front-end estatico e API"
  default_root_object = "index.html"
  price_class         = var.price_class

  origin {
    origin_id                = "s3-frontend"
    domain_name              = var.frontend_bucket_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend.id
  }

  origin {
    origin_id   = "api-gateway"
    domain_name = var.api_domain_name
    origin_path = "/${var.api_stage_name}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Site: cache longo, só leitura
  default_cache_behavior {
    target_origin_id           = "s3-frontend"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD", "OPTIONS"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.cache_otimizado.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.seguranca.id
  }

  # API: sem cache, todos os métodos, cabeçalho Authorization repassado (DECISIONS 8.2)
  ordered_cache_behavior {
    path_pattern               = "/api/*"
    target_origin_id           = "api-gateway"
    viewer_protocol_policy     = "https-only"
    allowed_methods            = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    cache_policy_id            = data.aws_cloudfront_cache_policy.sem_cache.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.todos_menos_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.seguranca.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.project_name}-cdn"
  }
}
