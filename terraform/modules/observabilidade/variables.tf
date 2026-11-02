variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "lambda_function_names" {
  description = "Funções Lambda monitoradas (apelido => nome da função)"
  type        = map(string)
}

variable "api_name" {
  description = "Nome da API REST no API Gateway"
  type        = string
}

variable "api_stage_name" {
  description = "Stage da API"
  type        = string
}

variable "pedidos_queue_name" {
  description = "Nome da fila de pedidos"
  type        = string
}

variable "pedidos_dlq_name" {
  description = "Nome da DLQ de pedidos"
  type        = string
}

variable "alarm_topic_arn" {
  description = "Tópico SNS que recebe alarmes e avisos de orçamento"
  type        = string
}

variable "budget_limit_usd" {
  description = "Limite mensal do orçamento, em dólares (valor de planejamento, não uma previsão de custo)"
  type        = number
  default     = 20
}

variable "xray_fixed_rate" {
  description = "Fração das requisições rastreadas pelo X-Ray, além da reserva de 1 por segundo"
  type        = number
  default     = 0.05
}
