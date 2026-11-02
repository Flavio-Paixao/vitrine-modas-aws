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
