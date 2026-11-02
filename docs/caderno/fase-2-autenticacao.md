# Caderno — Fase 2: Autenticação (Ticket VTM-6)

Flávio, esta fase cria o login dos clientes com o Amazon Cognito: um user pool, um app client para o front-end e dois grupos.

## Página 1 — O que vamos construir
- 1 **user pool** (`vitrine-modas-clientes`): onde ficam as contas.
- 1 **app client** (`vitrine-modas-web`): a "porta" que o front-end usa.
- 2 **grupos**: `clientes` e `admin`.
- **Plan esperado desta fase: 4 to add.** Somando as fases anteriores, o plan do projeto deve mostrar **22 to add** (se a Fase 1 deu 18). Se o seu número for diferente, cole a saída inteira.

## Página 2 — Autenticação x autorização
- **Autenticação:** provar quem você é (e-mail e senha, MFA). É o que o Cognito faz.
- **Autorização:** o que você pode fazer. Na Fase 3 a API usa o token e o grupo (`cognito:groups`) para decidir.

## Página 3 — Tokens
Depois do login o Cognito devolve três tokens:
- **ID token:** diz quem é o usuário (e-mail, grupos).
- **Access token:** autoriza chamadas.
- **Refresh token:** renova a sessão sem pedir senha de novo (30 dias aqui).
Os dois primeiros duram 60 minutos. O API Gateway valida o token sem consultar banco.

## Página 4 — Decisões de segurança
- Senha de 12+ caracteres com maiúscula, minúscula, número e símbolo (DECISIONS 5.3).
- MFA por app autenticador (TOTP), opcional. Por que não SMS? Custo e risco de troca de chip.
- Client público sem segredo: o navegador não guarda segredo (DECISIONS 5.4).
- `prevent_user_existence_errors`: não revela quais e-mails estão cadastrados.

## Página 5 — Comandos (sem `apply`)
```bash
cd ~/projetos/vitrine-modas-aws
git checkout main && git pull
git checkout -b VTM-6-autenticacao
tar xzf ~/Downloads/fase-2-autenticacao.tar.gz --strip-components=1 -C .
git status

cd terraform
terraform fmt -recursive
terraform init -backend=false
terraform validate
terraform plan 2>&1 | grep -E "^Plan:|Error"
cd ..
```
Esperado: `Plan: 22 to add, 0 to change, 0 to destroy.`

## Página 6 — Git e Jira
- Commit: `VTM-6: cognito user pool, app client e grupos`.
- PR para a `main`, 3 checks verdes, merge, VTM-6 em Done.

## Página 7 — Ligação com a prova SAA
- Cognito User Pool x Identity Pool: o primeiro autentica usuários; o segundo troca token por credenciais AWS temporárias.
- Cognito x IAM: IAM é para quem administra a AWS, Cognito é para os usuários da aplicação.
- MFA, tokens JWT, federação (login social) e SAML.

## Página 8 — Perguntas de entrevista
1. Por que Cognito e não um login feito por mim?
2. Qual a diferença entre User Pool e Identity Pool? (Eu usei só o User Pool.)
3. Por que o client não tem segredo?
4. Por que MFA por TOTP e não por SMS?
5. O que eu abri mão ao não usar Hosted UI? (DECISIONS 5.5)

## Checklist
- [ ] `terraform fmt` sem diferenças
- [ ] `terraform validate` com "Success"
- [ ] `terraform plan` com `22 to add` (ou colei a saída)
- [ ] CI verde no PR
- [ ] Ticket VTM-6 movido no Jira
