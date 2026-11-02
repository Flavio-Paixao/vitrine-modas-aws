# ==========================================
# Fase 3 (VTM-7): Funções Lambda (Python)
# ==========================================
# Cada função tem a sua role, com acesso só às tabelas de que precisa (DECISIONS 6.2).

locals {
  lambdas_dir = "${path.root}/../src/lambdas"

  kms_actions = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
}

# ---------- catalogo ----------
data "aws_iam_policy_document" "catalogo" {
  statement {
    sid     = "ProdutosLeituraEEscrita"
    actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:Scan"]
    resources = [
      module.dynamodb.produtos_table_arn,
      module.dynamodb.produtos_categoria_index_arn,
    ]
  }

  statement {
    sid       = "UsarChaveDoDynamoDB"
    actions   = local.kms_actions
    resources = [module.kms.dynamodb_key_arn]
  }
}

module "fn_catalogo" {
  source = "./modules/lambda_function"

  function_name = "${var.project_name}-catalogo"
  source_dir    = "${local.lambdas_dir}/catalogo"
  policy_json   = data.aws_iam_policy_document.catalogo.json

  environment = {
    TABELA_PRODUTOS  = module.dynamodb.produtos_table_name
    INDICE_CATEGORIA = module.dynamodb.categoria_index_name
  }
}

# ---------- estoque ----------
data "aws_iam_policy_document" "estoque" {
  statement {
    sid       = "EstoqueConsultaEReposicao"
    actions   = ["dynamodb:Query", "dynamodb:UpdateItem"]
    resources = [module.dynamodb.estoque_table_arn]
  }

  statement {
    sid       = "UsarChaveDoDynamoDB"
    actions   = local.kms_actions
    resources = [module.kms.dynamodb_key_arn]
  }
}

module "fn_estoque" {
  source = "./modules/lambda_function"

  function_name = "${var.project_name}-estoque"
  source_dir    = "${local.lambdas_dir}/estoque"
  policy_json   = data.aws_iam_policy_document.estoque.json

  environment = {
    TABELA_ESTOQUE = module.dynamodb.estoque_table_name
  }
}

# ---------- pedidos ----------
data "aws_iam_policy_document" "pedidos" {
  statement {
    sid       = "LerPrecoNoCatalogo"
    actions   = ["dynamodb:GetItem"]
    resources = [module.dynamodb.produtos_table_arn]
  }

  statement {
    sid       = "BaixarEstoque"
    actions   = ["dynamodb:UpdateItem"]
    resources = [module.dynamodb.estoque_table_arn]
  }

  statement {
    sid     = "GravarEConsultarPedidos"
    actions = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:Query"]
    resources = [
      module.dynamodb.pedidos_table_arn,
      module.dynamodb.pedidos_cliente_index_arn,
    ]
  }

  statement {
    sid       = "UsarChaveDoDynamoDB"
    actions   = local.kms_actions
    resources = [module.kms.dynamodb_key_arn]
  }
}

module "fn_pedidos" {
  source = "./modules/lambda_function"

  function_name = "${var.project_name}-pedidos"
  source_dir    = "${local.lambdas_dir}/pedidos"
  policy_json   = data.aws_iam_policy_document.pedidos.json

  environment = {
    TABELA_PRODUTOS = module.dynamodb.produtos_table_name
    TABELA_ESTOQUE  = module.dynamodb.estoque_table_name
    TABELA_PEDIDOS  = module.dynamodb.pedidos_table_name
    INDICE_CLIENTE  = module.dynamodb.pedidos_cliente_index_name
  }
}
