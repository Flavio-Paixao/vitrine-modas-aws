# ==========================================
# VARIÁVEIS DA RAIZ
# ==========================================

variable "aws_region" {
  description = "Região AWS (São Paulo: latência baixa para o público brasileiro)"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome do projeto (prefixo de todos os recursos)"
  type        = string
  default     = "vitrine-modas"
}

variable "environment" {
  description = "Ambiente (prod, staging, dev)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment deve ser prod, staging ou dev."
  }
}
