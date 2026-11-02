# ==========================================
# Fase 3 (VTM-7): API Gateway
# ==========================================

module "api" {
  source = "./modules/api"

  project_name  = var.project_name
  user_pool_arn = module.cognito.user_pool_arn

  functions = {
    catalogo = {
      invoke_arn    = module.fn_catalogo.invoke_arn
      function_name = module.fn_catalogo.function_name
    }
    estoque = {
      invoke_arn    = module.fn_estoque.invoke_arn
      function_name = module.fn_estoque.function_name
    }
    pedidos = {
      invoke_arn    = module.fn_pedidos.invoke_arn
      function_name = module.fn_pedidos.function_name
    }
  }
}
