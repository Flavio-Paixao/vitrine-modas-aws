variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "logs_kms_key_arn" {
  description = "ARN da chave KMS que criptografa o bucket de logs"
  type        = string
}

variable "log_retention_days" {
  description = "Dias até apagar os logs"
  type        = number
  default     = 365
}

variable "frontend_noncurrent_retention_days" {
  description = "Dias até apagar versões antigas dos arquivos do front-end"
  type        = number
  default     = 30
}

variable "frontend_extra_policy_json" {
  description = "Policy JSON extra do bucket do front-end (ex.: leitura pelo CloudFront), combinada com a de TLS"
  type        = string
  default     = null
}
