# Caderno — Fase 5: Borda (Ticket VTM-9)

Flávio, esta fase põe o CloudFront na frente de tudo: o site estático (S3) e a API respondem no mesmo endereço.

## Página 1 — O que vamos construir
- 1 **distribuição CloudFront** com duas origens: o bucket S3 do front-end (privado, via OAC) e o API Gateway (caminho `/api/*`).
- 1 **OAC** (Origin Access Control) e a policy do bucket combinada com a de TLS.
- 1 página `frontend/index.html` de demonstração, enviada ao bucket.
- **Plan desta fase: 3 to add. Total do projeto: 98 to add.**

Atenção: neste projeto o `plan` consulta a AWS para ler as políticas gerenciadas do CloudFront. Por isso o `plan` precisa de credenciais válidas (você já usa). Eu só consegui conferir a contagem com essas políticas simuladas, então o seu `plan` é o que vale.

## Página 2 — O caminho de uma requisição
```
navegador -> CloudFront (HTTPS, cabeçalhos de segurança)
   /            -> S3 (index.html), com cache
   /api/*       -> API Gateway (stage v1), sem cache, repassando Authorization
```

## Página 3 — Por que o bucket continua privado
O bucket não tem acesso público. O CloudFront assina as requisições (OAC) e a policy do bucket só deixa **esta distribuição** ler (`AWS:SourceArn`). Como o bucket só pode ter uma policy, ela é a soma da regra de TLS obrigatório com a do CloudFront (`source_policy_documents`).

## Página 4 — Conceitos
- **CDN/edge:** cópias de arquivos em pontos próximos do usuário; menos latência e menos carga na origem.
- **OAC x OAI:** OAC é o mecanismo atual (assinatura SigV4); OAI é o antigo.
- **Cache policy x origin request policy:** a primeira decide o que entra na chave de cache e por quanto tempo; a segunda decide o que é repassado à origem.
- **Same-origin:** site e API no mesmo domínio dispensam CORS.

## Página 5 — O que ficou de fora (e você explica)
Sem domínio próprio e ACM, sem WAF, sem access log, sem failover, sem restrição geográfica (DECISIONS 8.4). Sem redirecionamento de 403/404 para `index.html`, para não mascarar erros da API (DECISIONS 8.6).

## Página 6 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-9-borda
tar xzf ~/Downloads/fase-5-borda.tar.gz --strip-components=1 -C .
cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
cd ..
```
Esperado: `Plan: 98 to add, 0 to change, 0 to destroy.`

## Página 7 — Git e Jira
- Commit: `VTM-9: cloudfront com oac no front-end`.
- PR para a `main`; 4 checks verdes; merge; VTM-9 em Done.

## Página 8 — Ligação com a prova SAA
- CloudFront: origens, behaviors, cache e políticas, OAC, HTTPS, classes de preço.
- S3 privado + CloudFront x S3 website público.
- WAF, Shield e ACM (o que você deixaria para produção).

## Página 9 — Perguntas de entrevista
1. Por que o bucket é privado e como o CloudFront o lê?
2. Por que `/api/*` não tem cache?
3. Por que não precisei configurar CORS?
4. O que falta para este desenho ir para produção? (domínio, ACM, WAF, logs)
5. Por que `PriceClass_All`? O que isso custa?

## Checklist
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `98 to add`
- [ ] CI com 4 checks verdes
- [ ] Ticket VTM-9 movido no Jira
