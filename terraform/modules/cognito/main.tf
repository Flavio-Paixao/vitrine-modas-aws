# ==========================================
# USER POOL: cadastro e login dos clientes
# ==========================================
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-clientes"

  # Login com e-mail (DECISIONS 5.2)
  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  username_configuration {
    case_sensitive = false
  }

  # Senha forte (DECISIONS 5.3)
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_uppercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  # MFA por app autenticador (TOTP), opcional por padrão (DECISIONS 5.3)
  mfa_configuration = var.mfa_configuration

  software_token_mfa_configuration {
    enabled = true
  }

  # Recuperação de conta só pelo e-mail verificado
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # O cliente se cadastra sozinho (autocadastro permitido)
  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  tags = {
    Name = "${var.project_name}-clientes"
  }
}

# ==========================================
# APP CLIENT: o front-end conversa com o user pool por aqui
# ==========================================
# Cliente público (SPA): não tem segredo, porque tudo que roda no navegador é visível
# para quem abre o código (DECISIONS 5.4).
resource "aws_cognito_user_pool_client" "web" {
  name         = "${var.project_name}-web"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false

  # SRP: a senha nunca trafega em texto puro; refresh renova a sessão
  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  supported_identity_providers = ["COGNITO"]

  # Não revela se um e-mail existe ou não ao errar o login
  prevent_user_existence_errors = "ENABLED"
  enable_token_revocation       = true

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 30

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# ==========================================
# GRUPOS: quem pode o quê (usados pela API na Fase 3)
# ==========================================
resource "aws_cognito_user_group" "clientes" {
  name         = "clientes"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Clientes da loja: consultam o catálogo e fazem pedidos"
}

resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.main.id
  description  = "Equipe da loja: altera catálogo e estoque"
}
