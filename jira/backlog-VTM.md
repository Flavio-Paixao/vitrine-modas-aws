# Backlog Jira — projeto VTM (Kanban: To Do / In Progress / Ready to Deploy / Done)

Criar o projeto Kanban com a chave **VTM** e as Epics abaixo.

| Epic | Fase |
|---|---|
| VTM-1 | Fundação |
| VTM-2 | Dados (DynamoDB) |
| VTM-3 | Autenticação (Cognito) |
| VTM-4 | API e Lambdas |
| VTM-5 | Eventos (EventBridge, SNS, SQS) |
| VTM-6 | Borda (CloudFront + S3) |
| VTM-7 | Observabilidade |
| VTM-8 | Documentação final |

Os tickets filhos recebem os números seguintes quando você criar (a chave real pode mudar). Ajuste o nome da branch para a chave que o Jira gerar.

## Tickets da Fase 0 (filhos da Epic VTM-1)
1. Estruturar o repositório, `.gitignore`, `.tflint.hcl` e CI
2. Módulo `kms` adaptado do Case 1 (chaves DynamoDB e S3)
3. Módulo `storage` adaptado do Case 1 (frontend e logs)
4. Root module (`versions`, `variables`, `main`, `outputs`)
5. DECISIONS.md e README iniciais
