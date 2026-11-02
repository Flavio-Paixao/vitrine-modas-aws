# Caderno — Fase 3: API e Lambdas (Ticket VTM-7)

Flávio, esta fase coloca o "cérebro" do e-commerce: três funções Lambda em Python atrás de uma API REST protegida pelo Cognito.

## Página 1 — O que vamos construir
- 3 funções Lambda (Python 3.12, arm64): `catalogo`, `estoque` e `pedidos`, cada uma com a sua role.
- 1 API Gateway REST com 8 rotas, authorizer do Cognito e limite de requisições.
- Testes automáticos (`pytest` com `moto`) e um job novo no CI.
- **Plan desta fase: 47 to add. Total do projeto: 69 to add.** Conferi com `fmt`, `validate`, `plan` e `checkov` em um simulador da AWS; o seu `plan` na sua máquina é o que vale.

## Página 2 — As rotas
| Rota | Quem acessa | Função |
|---|---|---|
| `GET /api/produtos` (`?categoria=`) | público | catalogo |
| `GET /api/produtos/{produto_id}` | público | catalogo |
| `PUT /api/produtos/{produto_id}` | grupo `admin` | catalogo |
| `GET /api/estoque/{produto_id}` | público | estoque |
| `PUT /api/estoque/{produto_id}/{sku}` | grupo `admin` | estoque |
| `POST /api/pedidos` | cliente logado | pedidos |
| `GET /api/pedidos` | cliente logado (só os dele) | pedidos |
| `GET /api/pedidos/{pedido_id}` | cliente logado (só o dele) | pedidos |

## Página 3 — Estoque consistente (o coração do case)
`POST /api/pedidos` faz uma **transação** no DynamoDB: baixa o estoque de todos os itens com a condição `quantidade >= pedido` e grava o pedido. Tudo ou nada. Se faltar um item, a API responde 409 e nada é baixado. Os testes cobrem: último item vendido duas vezes, pedido com um item sem estoque e preço vindo do catálogo (não do cliente).

## Página 4 — Segurança em camadas
1. API Gateway valida o token do Cognito antes da Lambda.
2. A Lambda confere o grupo (`admin`) e o dono do pedido.
3. Cada função tem uma role com acesso só às tabelas dela.
4. A key policy da chave KMS só aceita uso via DynamoDB.
5. Limite de 100 req/s por rota (valor de estudo, não medido).

## Página 5 — Rodar os testes (na sua máquina)
```bash
cd ~/projetos/vitrine-modas-aws
python -m venv .venv
source .venv/Scripts/activate        # Git Bash no Windows
pip install -r requirements-dev.txt
pytest -q tests
```
Esperado: `8 passed`. Antes do commit, confira que `.venv` não aparece no `git status`; se aparecer, adicione `.venv/` ao `.gitignore`.

## Página 6 — Comandos (sem `apply`)
```bash
git checkout main && git pull
git checkout -b VTM-7-api-lambdas
tar xzf ~/Downloads/fase-3-api-lambdas.tar.gz --strip-components=1 -C .
cd terraform
terraform fmt -recursive
terraform init -backend=false -upgrade     # provider novo: archive
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
cd ..
git status                                   # inclua o .terraform.lock.hcl atualizado
```
Esperado: `Plan: 69 to add, 0 to change, 0 to destroy.`

## Página 7 — Git e Jira
- Commit: `VTM-7: api gateway e lambdas em python`.
- PR para a `main`; agora o CI tem **4 checks**: fmt + validate, tflint, checkov e python.
- Mova VTM-7: In Progress → Ready to Deploy (plan validado) → Done (PR mergeado).

## Página 8 — Ligação com a prova SAA
- Lambda: modelo de execução, cold start, concorrência, roles de execução, X-Ray.
- API Gateway: REST x HTTP API, authorizers (Cognito, Lambda), throttling, stages.
- DynamoDB: transações, escrita condicional, GSI.
- Princípio do menor privilégio: uma role por função.

## Página 9 — Perguntas de entrevista
1. Como você evita vender o mesmo item duas vezes? (transação + condição)
2. Por que o preço não vem do cliente?
3. Por que REST API e não HTTP API? O que você abriu mão?
4. Por que uma role por função?
5. Por que as Lambdas não estão em VPC?
6. O que os testes com `moto` provam e o que não provam? (DECISIONS 6.10)
7. Por que não há CORS? (DECISIONS 6.8)

## Checklist
- [ ] `pytest` com 8 testes passando
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `69 to add`
- [ ] `.terraform.lock.hcl` no commit
- [ ] CI com 4 checks verdes
- [ ] Ticket VTM-7 movido no Jira
