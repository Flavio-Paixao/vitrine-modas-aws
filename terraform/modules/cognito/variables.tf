variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "vitrine-modas"
}

variable "mfa_configuration" {
  description = "MFA do user pool: OFF, OPTIONAL ou ON"
  type        = string
  default     = "OPTIONAL"

  validation {
    condition     = contains(["OFF", "OPTIONAL", "ON"], var.mfa_configuration)
    error_message = "mfa_configuration deve ser OFF, OPTIONAL ou ON."
  }
}
