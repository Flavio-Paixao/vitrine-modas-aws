# ==========================================
# Fase 0 (VTM-1): Fundação
# ==========================================

# Chaves KMS (uma por finalidade: DynamoDB e S3)
module "kms" {
  source = "./modules/kms"

  project_name = var.project_name
}

# Buckets S3 (front-end estático e logs)
module "storage" {
  source = "./modules/storage"

  project_name     = var.project_name
  logs_kms_key_arn = module.kms.s3_key_arn
}

# ==========================================
# Fase 1 (VTM-5): Dados
# ==========================================

# Tabelas DynamoDB (produtos, estoque, pedidos), criptografadas com a chave KMS do DynamoDB
module "dynamodb" {
  source = "./modules/dynamodb"

  project_name = var.project_name
  kms_key_arn  = module.kms.dynamodb_key_arn
}
