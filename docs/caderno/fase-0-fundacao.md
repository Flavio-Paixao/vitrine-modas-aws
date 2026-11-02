# Caderno — Fase 0: Fundação (Epic VTM-1)

Flávio, esta fase monta a base: duas chaves KMS e dois buckets S3. Nada aqui é "serverless" ainda, mas as fases seguintes dependem disto.

## Página 1 — O que vamos construir
- 2 chaves KMS (DynamoDB e S3), cada uma com alias e rotação anual.
- 2 buckets S3: front-end (SSE-S3) e logs (SSE-KMS).
- **Plan esperado: 15 to add** (KMS: 2 chaves + 2 aliases = 4; front-end: bucket, bloqueio público, versionamento, criptografia, ciclo de vida = 5; logs: bucket, bloqueio público, criptografia, ciclo de vida = 4; 2 policies de TLS). Se o seu `plan` mostrar outro número, cole a saída inteira aqui.

## Página 2 — Chave KMS e key policy
Uma chave KMS criptografa dados em repouso. A **key policy** é a "porta" da chave: diferente de outros recursos, sem ela nem o IAM da conta consegue usar a chave.
- Separamos quem **administra** de quem **usa**.
- `kms:ViaService` faz a chave só funcionar quando a chamada vem do DynamoDB (ou do S3). Mesmo quem tem `kms:Decrypt` no IAM não abre os dados chamando o KMS direto.
- Por que duas chaves? Raio de impacto menor e trilha de auditoria separada.

## Página 3 — Buckets S3
- **Bloqueio de acesso público** (4 travas) em todos.
- **Versionamento** no front-end: dá para voltar a um deploy anterior. Nos logs não, de propósito.
- **Ciclo de vida:** controla custo (logs vão para Glacier em 90 dias e expiram em 365).
- **TLS obrigatório:** `Deny` quando `aws:SecureTransport` é falso.
- **Por que o front-end usa SSE-S3 e não KMS?** Ver DECISIONS 3.2.

## Página 4 — Comandos (sem `apply`)
```bash
git checkout -b VTM-1-fundacao        # troque pela chave que o Jira gerar
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan                        # precisa de credenciais AWS; cole a saída inteira se houver erro
```
O `plan` só lê e calcula; ele não cria nada. Confira a linha final: `Plan: 15 to add, 0 to change, 0 to destroy.`

## Página 5 — Git e Jira
- Branch e commits com a chave do ticket: `VTM-1: módulo kms adaptado do Seguros Horizonte`.
- Mova o ticket: To Do → In Progress → Ready to Deploy → Done. Como o projeto não tem `apply`, "Ready to Deploy" significa "plan validado".
- Depois do primeiro `init`, faça commit do `.terraform.lock.hcl` (o `.gitignore` não o bloqueia) para travar a versão do provider.

## Página 6 — Ligação com a prova SAA
- KMS: CMK x chaves gerenciadas pela AWS, key policy x IAM, rotação, grants.
- S3: SSE-S3 x SSE-KMS x SSE-C, bucket policy, Block Public Access, ciclo de vida e classes de armazenamento, versionamento.
- Princípio do menor privilégio e defesa em camadas.

## Página 7 — Perguntas de entrevista
1. Por que duas chaves KMS em vez de uma?
2. Por que o front-end não usa KMS?
3. O que `kms:ViaService` impede?
4. Por que o state ficou local e o `apply` nunca roda? (Resposta honesta: é um projeto de estudo validado com `plan`.)

## Checklist
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `15 to add` (ou colei a saída)
- [ ] CI do GitHub verde (fmt, validate, tflint, checkov)
- [ ] Ticket movido no Jira
