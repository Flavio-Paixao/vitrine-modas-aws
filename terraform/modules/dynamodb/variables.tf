variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "kms_key_arn" {
  description = "ARN da chave KMS que criptografa as tabelas"
  type        = string
}
