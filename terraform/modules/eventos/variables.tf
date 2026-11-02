variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "messaging_kms_key_arn" {
  description = "ARN da chave KMS que cifra o tópico SNS"
  type        = string
}

variable "alert_email" {
  description = "E-mail que recebe os alertas (opcional; null = sem assinatura)"
  type        = string
  default     = null
}

variable "max_receive_count" {
  description = "Tentativas de processar uma mensagem antes de ir para a DLQ"
  type        = number
  default     = 3
}

variable "queue_visibility_timeout" {
  description = "Segundos que a mensagem fica invisível durante o processamento (>= 6x o timeout da Lambda)"
  type        = number
  default     = 60
}
