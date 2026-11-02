# Caderno — Fase 4: Eventos (Ticket VTM-8)

Flávio, esta fase faz o sistema reagir sozinho a mudanças: quando um pedido nasce ou o estoque fica baixo, um evento dispara o próximo passo, sem uma função chamar a outra.

## Página 1 — O que vamos construir
- Um barramento **EventBridge** (`vitrine-modas-eventos`) com 2 regras.
- Uma fila **SQS** de pedidos com **DLQ**, e um tópico **SNS** de alertas (cifrado com a chave nova `messaging`).
- 2 Lambdas: `publicador` (stream do DynamoDB para EventBridge) e `processador` (fila de pedidos, confirma o pedido).
- O stream de `pedidos` foi ligado na tabela (mudança no módulo `dynamodb`).
- **Plan desta fase: 26 to add. Total do projeto: 95 to add.** Conferi com `fmt`, `validate`, `plan` e `checkov` em um simulador da AWS; o seu `plan` é o que vale.

## Página 2 — O fluxo
```
cliente faz POST /api/pedidos
  -> Lambda pedidos grava pedido + baixa estoque (transação)
  -> DynamoDB Streams (pedidos, estoque, produtos)
  -> Lambda publicador -> EventBridge (PedidoCriado, EstoqueAlterado, EstoqueBaixo, ...)
       regra PedidoCriado  -> fila SQS -> Lambda processador -> pedido CONFIRMADO
       regra EstoqueBaixo  -> tópico SNS -> e-mail (se você assinar)
```

## Página 3 — Conceitos
- **Evento:** um fato que já aconteceu ("pedido criado"). Quem produz não sabe quem escuta.
- **EventBridge:** barramento com regras que filtram eventos e os enviam a destinos.
- **SQS:** fila que guarda mensagens até alguém processar. **DLQ:** fila de mensagens que falharam 3 vezes.
- **SNS:** publica uma mensagem para vários assinantes (e-mail, fila, função).
- **Idempotência:** processar a mesma mensagem duas vezes dá o mesmo resultado. É obrigatória, porque a entrega é "pelo menos uma vez".

## Página 4 — Limites que você precisa saber explicar
- Eventos podem chegar repetidos e fora de ordem (DECISIONS 7.3).
- Se o publicador falhar 3 vezes no mesmo lote do stream, o lote é descartado (não há fila de falhas nos streams). É uma limitação consciente.
- A política da chave KMS do tópico só se prova num `apply`; o `plan` não prova (DECISIONS 7.4).
- O "processamento" é só a confirmação do pedido: sem pagamento nem envio (DECISIONS 7.8).

## Página 5 — Receber alertas por e-mail (opcional)
O e-mail **não** vai para o código. Se quiser testar o `plan` com a assinatura:
```bash
terraform plan -var="alert_email=seu-email@exemplo.com" 2>&1 | grep -E "^Plan:|Error"
```
Com o e-mail, o plan terá **1 recurso a mais** (a assinatura). Nunca salve o e-mail em `*.tfvars` no git (o `.gitignore` já bloqueia `*.tfvars`).

## Página 6 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-8-eventos
tar xzf ~/Downloads/fase-4-eventos.tar.gz --strip-components=1 -C .
source .venv/Scripts/activate && pytest -q tests     # 14 testes
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
cd ..
```
Esperado: `Plan: 95 to add, 0 to change, 0 to destroy.`

## Página 7 — Git e Jira
- Commit: `VTM-8: eventbridge, sns e sqs`.
- PR para a `main`; 4 checks verdes (fmt + validate, tflint, checkov, python). Merge. VTM-8 em Done.

## Página 8 — Ligação com a prova SAA
- SQS padrão x FIFO, visibility timeout, DLQ, long polling.
- SNS x SQS x EventBridge: quando usar cada um (fan-out, desacoplamento, roteamento por regra).
- Arquitetura orientada a eventos, entrega pelo menos uma vez, idempotência.
- KMS com serviços da AWS (key policy para `events`/`cloudwatch`).

## Página 9 — Perguntas de entrevista
1. Por que EventBridge e não chamar a outra Lambda direto?
2. O que é uma DLQ e quando uma mensagem vai para ela?
3. Como o consumidor evita efeito duplo se a mensagem chegar duas vezes?
4. Por que o alerta de estoque só dispara ao cruzar o limite?
5. Qual é a limitação dos streams sem destino de falha? Como você resolveria em produção?
6. Por que SQS com SSE-SQS e SNS com chave própria?

## Checklist
- [ ] 14 testes passando
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `95 to add`
- [ ] CI com 4 checks verdes
- [ ] Ticket VTM-8 movido no Jira
