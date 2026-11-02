# ==========================================
# Fase 6 (VTM-10): Observabilidade
# ==========================================

variable "budget_limit_usd" {
  description = "Limite mensal do orçamento, em dólares (valor de planejamento)"
  type        = number
  default     = 20
}

module "observabilidade" {
  source = "./modules/observabilidade"

  project_name = var.project_name

  lambda_function_names = {
    catalogo    = module.fn_catalogo.function_name
    estoque     = module.fn_estoque.function_name
    pedidos     = module.fn_pedidos.function_name
    publicador  = module.fn_publicador.function_name
    processador = module.fn_processador.function_name
  }

  api_name           = module.api.rest_api_name
  api_stage_name     = module.api.stage_name
  pedidos_queue_name = module.eventos.pedidos_queue_name
  pedidos_dlq_name   = module.eventos.pedidos_dlq_name
  alarm_topic_arn    = module.eventos.alertas_topic_arn
  budget_limit_usd   = var.budget_limit_usd
}
