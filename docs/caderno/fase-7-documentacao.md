# Caderno — Fase 7: Documentação final (Ticket VTM-11)

Flávio, esta fase não cria recursos: ela transforma o que você construiu em um portfólio que um recrutador entende em 2 minutos, **sem prometer nada que você não provou**.

## Página 1 — O que vem no pacote
- `README.md` final (substitui o seu), com a tabela problema/decisão e os limites conhecidos.
- `docs/ARCHITECTURE.md`, com dois diagramas Mermaid (o GitHub desenha sozinho).
- `docs/arquitetura.svg`, o diagrama da arquitetura (aparece no README).
- `docs/COST-ANALYSIS.md`, o método de estimativa de custo.
- `docs/DECISIONS.md` já veio completo da Fase 6; aqui você só revisa.
- **Plan desta fase: nenhum** (só documentação).

## Página 2 — Revisão de honestidade (faça antes de commitar)
Leia o README e o ARCHITECTURE e confira cada afirmação:
- [ ] "Validado com fmt, validate, plan, tflint, checkov e testes": você rodou todos? O CI está verde?
- [ ] O seu `plan` final deu `108 to add`? (O README não cita o número; se quiser citar, use o **seu**.)
- [ ] Nenhuma frase diz "em produção", "usuários", "latência", "disponibilidade" ou "economia".
- [ ] Os limites conhecidos (README) batem com o que você consegue explicar.

## Página 3 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-11-documentacao
tar xzf ~/Downloads/fase-7-documentacao.tar.gz --strip-components=1 -C .
git status                      # README.md, docs/ e nada de terraform/
git add .
git commit -m "VTM-11: documentação final"
git push -u origin VTM-11-documentacao
```
Abra o PR, confira no GitHub se o **diagrama SVG aparece no README** e se os **diagramas Mermaid** do ARCHITECTURE renderizam. Se um Mermaid der erro de sintaxe, me mande a mensagem.

## Página 4 — Depois do merge
- Descrição do repositório: `Serverless fashion e-commerce on AWS (sa-east-1) with modular Terraform. Study project validated with plan.` e topics: `aws` `terraform` `serverless` `lambda` `python` `dynamodb` `api-gateway` `cognito` `cloudfront` `infrastructure-as-code`.
- Fixe o repositório no seu perfil do GitHub.
- Currículo (frase honesta): "Projeto de estudo: e-commerce serverless na AWS com Terraform em módulos (Lambda em Python, DynamoDB, API Gateway, Cognito, EventBridge, SQS/SNS, CloudFront), validado com `terraform plan`, checkov e testes automatizados; não implantado."

## Página 5 — Perguntas de entrevista (visão do projeto inteiro)
1. Resuma a arquitetura em 1 minuto: problema, serviços, fluxo de uma compra.
2. Como o estoque fica consistente no pico?
3. Qual foi a decisão mais difícil e o que você abriu mão?
4. O que você não usou e por quê? (RDS, ElastiCache, EC2, Step Functions, WAF...)
5. O que o seu `plan` prova e o que ele não prova?
6. O que mudaria para ir a produção? (domínio, ACM, WAF, logs, falhas de stream, pipeline de deploy, ambientes)
7. Como você estimaria o custo? (COST-ANALYSIS: método, sem números inventados)

## Checklist final do Case 2
- [ ] Fases 0 a 6 mergeadas, CI verde
- [ ] Documentação revisada e mergeada
- [ ] Descrição e topics do repositório ajustados
- [ ] Repositório fixado no perfil
- [ ] Respostas de entrevista ensaiadas em voz alta
- [ ] Ticket VTM-11 em Done
