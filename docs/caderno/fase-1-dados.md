# Caderno — Fase 1: Dados (Ticket VTM-5)

Flávio, esta fase cria o "banco" do e-commerce: três tabelas DynamoDB criptografadas com a chave KMS da Fase 0.

## Página 1 — O que vamos construir
- `vitrine-modas-produtos` (catálogo), com índice por categoria e Streams.
- `vitrine-modas-estoque` (uma linha por tamanho/cor), com Streams.
- `vitrine-modas-pedidos`, com índice por cliente.
- **Plan esperado desta fase: 3 to add.** Somando a Fase 0, o plan do projeto deve mostrar **18 to add**. Se o seu número for diferente, cole a saída inteira aqui.

## Página 2 — DynamoDB em 5 minutos
- Tabela de chave-valor/documento: você busca pela **chave**, não por joins.
- **Chave de partição** (hash) escolhe onde o item mora; **chave de classificação** (range) ordena itens da mesma partição.
- **GSI** (índice secundário global) é uma "segunda visão" da tabela com outra chave, para outra consulta.
- **Modo sob demanda**: sem capacidade fixa; ideal para tráfego imprevisível como a Black Friday (DECISIONS 4.1).

## Página 3 — Estoque consistente
O Terraform só cria a tabela. A regra "não vender o que não tem" é código: na Fase 3 a Lambda fará `UpdateItem` com `ConditionExpression: quantidade >= :qtd`. Se a condição falhar, a escrita é rejeitada e ninguém compra o último item duas vezes (DECISIONS 4.4).

## Página 4 — Streams
Cada alteração em `produtos` e `estoque` gera um registro no stream (item antes e depois). Na Fase 4 isso alimenta eventos para o resto do sistema, sem que as tabelas precisem conhecer quem consome.

## Página 5 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-5-dados
# copie os arquivos da fase 1 por cima do repositório (mesmos caminhos)
cd terraform
terraform fmt -recursive
terraform init -backend=false      # sem novos providers, deve ser rápido
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
```
Esperado: `Plan: 18 to add, 0 to change, 0 to destroy.`

## Página 6 — Git e Jira
- Branch `VTM-5-dados`; commits com a chave do ticket: `VTM-5: módulo dynamodb com produtos, estoque e pedidos`.
- Abra o PR para a `main` e espere os três checks (fmt + validate, tflint, checkov) ficarem verdes.
- Mova VTM-5: To Do → In Progress → Ready to Deploy (plan validado) → Done (PR mergeado).

## Página 7 — Ligação com a prova SAA
- DynamoDB: chaves, GSI x LSI, modo sob demanda x provisionado, Streams, PITR, criptografia com KMS.
- Quando usar banco relacional x NoSQL; consistência eventual x forte em leituras.
- Desacoplamento orientado a eventos (preparação para a Fase 4).

## Página 8 — Perguntas de entrevista
1. Por que DynamoDB e não Aurora para estoque e pedidos? (acesso por chave, escala sem gerenciar servidor; abro mão de joins e SQL ad hoc)
2. Por que modo sob demanda? Quando eu trocaria para provisionado?
3. Como você evita vender o mesmo item duas vezes?
4. Por que três tabelas e não single-table design?
5. O que o `plan` prova e o que ele não prova sobre a chave KMS? (DECISIONS 4.6)

## Checklist
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `18 to add` (ou colei a saída)
- [ ] CI verde no PR
- [ ] Ticket VTM-5 movido no Jira
