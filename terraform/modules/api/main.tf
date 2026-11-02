data "aws_region" "current" {}

# ==========================================
# API REST (regional)
# ==========================================
resource "aws_api_gateway_rest_api" "this" {
  name = "${var.project_name}-api"

  lifecycle {
    create_before_destroy = true
  }

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Authorizer: valida o token do Cognito ANTES de chamar a Lambda (DECISIONS 6.7)
resource "aws_api_gateway_authorizer" "cognito" {
  name            = "cognito"
  rest_api_id     = aws_api_gateway_rest_api.this.id
  type            = "COGNITO_USER_POOLS"
  provider_arns   = [var.user_pool_arn]
  identity_source = "method.request.header.Authorization"
}

# ==========================================
# RECURSOS (caminhos). Tudo fica sob /api para o CloudFront rotear /api/* na Fase 5
# ==========================================
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_rest_api.this.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "produtos" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "produtos"
}

resource "aws_api_gateway_resource" "produtos_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.produtos.id
  path_part   = "{produto_id}"
}

resource "aws_api_gateway_resource" "estoque" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "estoque"
}

resource "aws_api_gateway_resource" "estoque_produto" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.estoque.id
  path_part   = "{produto_id}"
}

resource "aws_api_gateway_resource" "estoque_sku" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.estoque_produto.id
  path_part   = "{sku}"
}

resource "aws_api_gateway_resource" "pedidos" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "pedidos"
}

resource "aws_api_gateway_resource" "pedidos_id" {
  rest_api_id = aws_api_gateway_rest_api.this.id
  parent_id   = aws_api_gateway_resource.pedidos.id
  path_part   = "{pedido_id}"
}

# ==========================================
# ROTAS: método + Lambda. "publica" = sem login (vitrine aberta)
# ==========================================
locals {
  rotas = {
    "GET /api/produtos"                   = { recurso = aws_api_gateway_resource.produtos.id, metodo = "GET", funcao = "catalogo", publica = true }
    "GET /api/produtos/{produto_id}"      = { recurso = aws_api_gateway_resource.produtos_id.id, metodo = "GET", funcao = "catalogo", publica = true }
    "PUT /api/produtos/{produto_id}"      = { recurso = aws_api_gateway_resource.produtos_id.id, metodo = "PUT", funcao = "catalogo", publica = false }
    "GET /api/estoque/{produto_id}"       = { recurso = aws_api_gateway_resource.estoque_produto.id, metodo = "GET", funcao = "estoque", publica = true }
    "PUT /api/estoque/{produto_id}/{sku}" = { recurso = aws_api_gateway_resource.estoque_sku.id, metodo = "PUT", funcao = "estoque", publica = false }
    "POST /api/pedidos"                   = { recurso = aws_api_gateway_resource.pedidos.id, metodo = "POST", funcao = "pedidos", publica = false }
    "GET /api/pedidos"                    = { recurso = aws_api_gateway_resource.pedidos.id, metodo = "GET", funcao = "pedidos", publica = false }
    "GET /api/pedidos/{pedido_id}"        = { recurso = aws_api_gateway_resource.pedidos_id.id, metodo = "GET", funcao = "pedidos", publica = false }
  }
}

resource "aws_api_gateway_method" "rota" {
  #checkov:skip=CKV_AWS_59:GET do catalogo e do estoque sao publicos de proposito (DECISIONS 6.8)
  #checkov:skip=CKV2_AWS_53:Validacao de requisicao feita dentro da Lambda (DECISIONS 6.8)
  for_each = local.rotas

  rest_api_id   = aws_api_gateway_rest_api.this.id
  resource_id   = each.value.recurso
  http_method   = each.value.metodo
  authorization = each.value.publica ? "NONE" : "COGNITO_USER_POOLS"
  authorizer_id = each.value.publica ? null : aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "rota" {
  for_each = local.rotas

  rest_api_id             = aws_api_gateway_rest_api.this.id
  resource_id             = each.value.recurso
  http_method             = aws_api_gateway_method.rota[each.key].http_method
  integration_http_method = "POST" # a API chama a Lambda sempre com POST
  type                    = "AWS_PROXY"
  uri                     = var.functions[each.value.funcao].invoke_arn
}

# Permissão para o API Gateway invocar cada função
resource "aws_lambda_permission" "api" {
  for_each = var.functions

  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = each.value.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this.execution_arn}/*/*"
}

# ==========================================
# DEPLOYMENT E STAGE
# ==========================================
resource "aws_api_gateway_deployment" "this" {
  rest_api_id = aws_api_gateway_rest_api.this.id

  # Muda quando uma rota muda, para o Terraform criar um deployment novo
  triggers = {
    redeployment = sha1(jsonencode([
      for chave in sort(keys(local.rotas)) : [
        aws_api_gateway_method.rota[chave].id,
        aws_api_gateway_integration.rota[chave].id,
      ]
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "this" {
  #checkov:skip=CKV_AWS_76:Sem access log: exigiria a role de logs da conta (DECISIONS 6.8)
  #checkov:skip=CKV_AWS_120:Sem cache da API: o CloudFront cuida do cache (DECISIONS 6.8)
  #checkov:skip=CKV2_AWS_29:Sem WAF no projeto de estudo (DECISIONS 6.8)
  #checkov:skip=CKV2_AWS_51:Sem certificado de cliente (DECISIONS 6.8)
  #checkov:skip=CKV2_AWS_4:Sem log de execucao: exigiria a role de logs da conta (DECISIONS 6.8)
  rest_api_id   = aws_api_gateway_rest_api.this.id
  deployment_id = aws_api_gateway_deployment.this.id
  stage_name    = var.stage_name

  xray_tracing_enabled = true
}

# Limite de requisições: protege as Lambdas e a conta contra abuso (DECISIONS 6.9)
resource "aws_api_gateway_method_settings" "todas" {
  #checkov:skip=CKV_AWS_225:Sem cache na API (DECISIONS 6.8)
  rest_api_id = aws_api_gateway_rest_api.this.id
  stage_name  = aws_api_gateway_stage.this.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled        = true
    throttling_rate_limit  = var.throttling_rate_limit
    throttling_burst_limit = var.throttling_burst_limit
  }
}
