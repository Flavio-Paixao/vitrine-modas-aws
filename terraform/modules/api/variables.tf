variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "user_pool_arn" {
  description = "ARN do user pool do Cognito que autoriza as chamadas"
  type        = string
}

variable "functions" {
  description = "Funções Lambda atrás da API: catalogo, estoque e pedidos"
  type = map(object({
    invoke_arn    = string
    function_name = string
  }))
}

variable "stage_name" {
  description = "Nome do stage (aparece na URL)"
  type        = string
  default     = "v1"
}

variable "throttling_rate_limit" {
  description = "Requisições por segundo permitidas por rota"
  type        = number
  default     = 100
}

variable "throttling_burst_limit" {
  description = "Rajada máxima de requisições"
  type        = number
  default     = 200
}
