variable "function_name" {
  description = "Nome completo da função (ex.: vitrine-modas-catalogo)"
  type        = string
}

variable "source_dir" {
  description = "Pasta com o código Python da função (contém app.py)"
  type        = string
}

variable "policy_json" {
  description = "Policy IAM (JSON) com as permissões da função, além dos logs"
  type        = string
}

variable "environment" {
  description = "Variáveis de ambiente da função (sem segredos)"
  type        = map(string)
  default     = {}
}

variable "handler" {
  description = "Ponto de entrada: arquivo.função"
  type        = string
  default     = "app.handler"
}

variable "runtime" {
  description = "Runtime da função"
  type        = string
  default     = "python3.12"
}

variable "timeout" {
  description = "Tempo máximo de execução, em segundos"
  type        = number
  default     = 10
}

variable "memory_size" {
  description = "Memória da função, em MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 365
}
