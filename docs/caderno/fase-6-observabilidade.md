# Caderno — Fase 6: Observabilidade (Ticket VTM-10)

Flávio, esta fase responde a pergunta "como eu fico sabendo que algo deu errado?" e "quanto estou gastando?".

## Página 1 — O que vamos construir
- 7 **alarmes** no CloudWatch (erros de cada uma das 5 Lambdas, erros 5xx da API e mensagens na DLQ), todos avisando o tópico SNS de alertas.
- 1 **dashboard** de visão geral.
- 1 **orçamento** mensal no AWS Budgets (US$ 20, valor de planejamento).
- 1 **regra de amostragem** do X-Ray.
- **Plan desta fase: 10 to add. Total do projeto: 108 to add.** Como na Fase 5, só consegui conferir a contagem com as políticas do CloudFront simuladas; o seu `plan` é o que vale.

## Página 2 — Os três pilares
- **Métricas:** números ao longo do tempo (erros, invocações). Alimentam alarmes e dashboards.
- **Logs:** texto de cada execução (CloudWatch Logs, 365 dias).
- **Traços:** o caminho de uma requisição entre serviços (X-Ray).
Os três já existem; esta fase ensina o sistema a **avisar**.

## Página 3 — Como um alarme funciona
Uma métrica é avaliada a cada 5 minutos. Se passar do limite, o alarme muda de estado (OK, ALARM) e publica no tópico SNS. `notBreaching` significa que "sem dados" não é problema: numa loja pequena nem sempre há métrica.

## Página 4 — Honestidade sobre números
Os limites dos alarmes, a amostragem do X-Ray e o valor do orçamento são **escolhas de estudo**. Nenhuma foi calibrada com tráfego real, e este projeto não mede latência, disponibilidade ou custo real. Não coloque nenhum desses números no currículo como resultado (DECISIONS 9.5).

## Página 5 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-10-observabilidade
tar xzf ~/Downloads/fase-6-observabilidade.tar.gz --strip-components=1 -C .
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
cd ..
```
Esperado: `Plan: 108 to add, 0 to change, 0 to destroy.`

## Página 6 — Git e Jira
- Commit: `VTM-10: x-ray, alarmes e budgets`.
- PR para a `main`; 4 checks verdes; merge; VTM-10 em Done.

## Página 7 — Ligação com a prova SAA
- CloudWatch: métricas, alarmes, dashboards, Logs; X-Ray; AWS Budgets e Cost Explorer.
- Princípio de excelência operacional (Well-Architected): monitorar e responder a eventos.
- Otimização de custos: orçamentos, tags de alocação, classes de armazenamento.

## Página 8 — Perguntas de entrevista
1. Qual é a diferença entre métrica, log e traço?
2. Por que a DLQ tem alarme?
3. Por que o X-Ray tem amostragem?
4. O que o AWS Budgets faz e o que ele não faz? (avisa, não bloqueia)
5. O que você não monitorou e por quê? (DECISIONS 9.5)

## Checklist
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `108 to add`
- [ ] CI com 4 checks verdes
- [ ] Ticket VTM-10 movido no Jira
