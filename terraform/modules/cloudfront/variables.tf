variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "frontend_bucket_domain_name" {
  description = "Domínio regional do bucket S3 do front-end"
  type        = string
}

variable "api_domain_name" {
  description = "Domínio regional do API Gateway (sem https://)"
  type        = string
}

variable "api_stage_name" {
  description = "Stage do API Gateway (vira o caminho de origem)"
  type        = string
}

variable "price_class" {
  description = "Classe de preço do CloudFront (PriceClass_All inclui a América do Sul)"
  type        = string
  default     = "PriceClass_All"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class deve ser PriceClass_100, PriceClass_200 ou PriceClass_All."
  }
}
