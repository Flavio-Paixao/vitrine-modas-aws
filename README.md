# Vitrine Modas — e-commerce de moda serverless na AWS

Projeto de estudo (portfólio): arquitetura serverless para um e-commerce de moda fictício, na região `sa-east-1`, escrita em Terraform com módulos.

> **Status:** em construção, fase a fase. O código é validado com `terraform fmt`, `validate` e `plan`. **Nada foi implantado** (`apply` não é executado).

## O que existe até agora
- **Fase 0 (VTM-1), fundação:** módulo `kms` (chaves do DynamoDB e do S3) e módulo `storage` (buckets de front-end e de logs).

## Próximas fases
Dados (DynamoDB), autenticação (Cognito), API e Lambdas em Python, eventos (EventBridge, SNS, SQS), CloudFront, observabilidade.

## Documentação
- [DECISIONS.md](docs/DECISIONS.md): por que usei, por que não usei e o que abri mão.

## Como validar (sem credenciais e sem apply)
```bash
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
```
