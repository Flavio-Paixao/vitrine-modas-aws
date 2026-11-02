locals {
  # Nomes dos índices, usados também pelas Lambdas (via outputs)
  categoria_index = "categoria-index"
  cliente_index   = "cliente-index"
}

# ==========================================
# TABELA 1: PRODUTOS (catálogo)
# ==========================================
# Chave de partição: produto_id. O catálogo muda (preço, descrição, coleção), então a
# tabela tem Streams: cada alteração vira um evento que a Fase 4 vai consumir.
resource "aws_dynamodb_table" "produtos" {
  name         = "${var.project_name}-produtos"
  billing_mode = "PAY_PER_REQUEST" # paga por requisição: sem capacidade fixa para o pico (DECISIONS 4.1)
  hash_key     = "produto_id"

  attribute {
    name = "produto_id"
    type = "S"
  }

  attribute {
    name = "categoria"
    type = "S"
  }

  attribute {
    name = "nome"
    type = "S"
  }

  # Índice para listar produtos de uma categoria, ordenados por nome (DECISIONS 4.3)
  global_secondary_index {
    name            = local.categoria_index
    hash_key        = "categoria"
    range_key       = "nome"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES" # guarda o item antes e depois da mudança

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${var.project_name}-produtos"
  }
}

# ==========================================
# TABELA 2: ESTOQUE (uma linha por variação: tamanho/cor)
# ==========================================
# Chave composta: produto_id + sku. A consistência do estoque vem de escrita condicional
# (ConditionExpression quantidade >= pedido), feita pela Lambda na Fase 3 (DECISIONS 4.4).
resource "aws_dynamodb_table" "estoque" {
  name         = "${var.project_name}-estoque"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "produto_id"
  range_key    = "sku"

  attribute {
    name = "produto_id"
    type = "S"
  }

  attribute {
    name = "sku"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${var.project_name}-estoque"
  }
}

# ==========================================
# TABELA 3: PEDIDOS
# ==========================================
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project_name}-pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  attribute {
    name = "cliente_id"
    type = "S"
  }

  attribute {
    name = "criado_em"
    type = "S"
  }

  # Índice para listar os pedidos de um cliente, do mais novo para o mais antigo
  global_secondary_index {
    name            = local.cliente_index
    hash_key        = "cliente_id"
    range_key       = "criado_em"
    projection_type = "ALL"
  }

  # Stream: cada pedido novo vira o evento PedidoCriado (Fase 4)
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  tags = {
    Name = "${var.project_name}-pedidos"
  }
}
