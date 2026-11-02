# Decisões de arquitetura — Vitrine Modas

Projeto de estudo, validado com `terraform validate` e `terraform plan`. Nada foi implantado (`apply` nunca é executado).

## Sumário
1. Base do projeto
2. KMS
3. S3
4. DynamoDB
5. Cognito
6. Mudanças em relação ao Seguros Horizonte
7. Serviços que não usei (vai crescendo a cada fase)

## 1. Base do projeto

### 1.1 State local, sem backend remoto
Como o projeto nunca roda `apply`, não existe infraestrutura para guardar em state remoto. O `.gitignore` bloqueia `*.tfstate` e `*.tfvars`. Abro mão de praticar backend remoto (S3 com locking) neste case.

### 1.2 Provider AWS `~> 5.20`
Mesma versão do Case 1, para o código dos módulos adaptados continuar válido.

### 1.3 `default_tags` no provider
Tags de projeto, ambiente, dono e repositório aplicadas em todo recurso, sem repetir em cada módulo.

### 1.4 `environment` com padrão `dev`
No Case 1 o padrão era `prod`. Aqui o projeto não está implantado, então `dev` evita sugerir que existe um ambiente de produção.

## 2. KMS

### 2.1 Chaves próprias, uma por finalidade
Uma chave para o DynamoDB e outra para o S3. Se uma for desativada ou comprometida, a outra não é afetada, e cada uma tem a sua trilha no CloudTrail.

### 2.2 Key policy separando administrar de usar
Herdado do Case 1 (3.3): a conta administra a chave, mas só criptografa/descriptografa quando a chamada vem pelo serviço certo (`kms:ViaService`) e desta conta (`kms:CallerAccount`).

### 2.3 Grants só para recursos da AWS
O DynamoDB cria grants para usar a chave em segundo plano. A condição `kms:GrantIsForAWSResource` impede grants para pessoas.

### 2.4 `Resource = "*"` nas key policies (falso positivo do checkov)
Numa key policy, `*` significa "esta chave". Os skips `CKV_AWS_111` e `CKV_AWS_356` apontam para esta seção.

### 2.5 Chave de mensageria fica para a Fase 4
SNS e SQS precisam de permissões de serviço na key policy (EventBridge, SNS). Cria-se a chave quando os recursos existirem, para não escrever uma policy sem poder testar o desenho.

## 3. S3

### 3.1 Dois buckets: front-end e logs
O Case 1 tinha três (dados, backups, logs). Aqui os dados vivem no DynamoDB e não há banco para backup em S3.

### 3.2 Front-end com SSE-S3 (AES256), sem KMS
O conteúdo é público por natureza (será servido pelo CloudFront). Usar KMS exigiria ampliar a key policy para o CloudFront, que a policy herdada do Case 1 não permite (só aceita uso via S3), e não traria ganho. Abro mão de ter uma trilha de uso da chave para esse bucket. O skip `CKV_AWS_145` aponta para esta seção.

### 3.3 Logs com SSE-KMS e sem versionamento
Logs são só de acréscimo e não são editados. Sem versionamento, o ciclo de vida fica simples (90 dias até Glacier, expira em `log_retention_days`, padrão 365).

### 3.4 TLS obrigatório nos dois buckets
Policy de `Deny` quando `aws:SecureTransport` é falso. Herdado do Case 1.

### 3.5 Bucket policy do front-end será estendida na Fase 5
Um bucket só tem uma bucket policy. Na Fase 5 a permissão do CloudFront (OAC) será combinada com a policy de TLS usando `source_policy_documents`.

### 3.6 Sem replicação entre regiões, sem access logging, sem notificações de evento
Por custo e por não terem consumidor neste projeto. Os skips `CKV_AWS_144`, `CKV_AWS_18` e `CKV2_AWS_62` apontam para esta seção.

## 4. DynamoDB

### 4.1 Modo sob demanda (`PAY_PER_REQUEST`)
O tráfego tem pico sazonal (Black Friday) e longos períodos baixos. No modo sob demanda não preciso dimensionar capacidade nem configurar auto scaling, e pago por requisição. Abro mão da previsibilidade de custo e de custo menor com carga alta e constante (nesse caso a capacidade provisionada compensaria). Os valores reais de custo ficam para o COST-ANALYSIS, calculados a partir de preços publicados, sem números de uso inventados.

### 4.2 Três tabelas (produtos, estoque, pedidos), não single-table design
Uma tabela por entidade deixa o modelo fácil de explicar e de testar. O single-table design reduziria o número de tabelas e de consultas em alguns padrões de acesso, mas é mais difícil de ler e de evoluir. Abro mão dessa otimização por clareza de estudo.

### 4.3 Dois índices secundários globais (GSI)
- `categoria-index` (produtos): lista produtos de uma categoria, ordenados por nome.
- `cliente-index` (pedidos): lista os pedidos de um cliente por data de criação.
Cada GSI replica os dados (`projection_type = ALL`) e consome escrita extra. Aceito esse custo porque as duas consultas são o caso de uso principal.

### 4.4 Estoque por variação (`produto_id` + `sku`) e escrita condicional
Cada tamanho/cor é uma linha. A consistência do estoque não vem do Terraform, e sim da Lambda da Fase 3, que vai decrementar com `ConditionExpression` (só baixa se `quantidade` for suficiente). Assim duas compras simultâneas do último item não passam as duas.

### 4.5 Streams com `NEW_AND_OLD_IMAGES` em produtos e estoque
O catálogo e o estoque mudam, e a Fase 4 vai reagir a essas mudanças (EventBridge). Guardar o item antes e depois permite saber o que mudou (por exemplo, preço antigo e novo). Pedidos não tem stream por enquanto.

### 4.6 Chave KMS própria e recuperação pontual (PITR)
As tabelas usam a chave `dynamodb` criada na Fase 0 (em vez da chave gerenciada pela AWS), e o PITR fica ligado para poder restaurar a qualquer momento dos últimos 35 dias. A política da chave só aceita uso via DynamoDB (DECISIONS 2.2 e 2.3). Isso só é exercitado de verdade em um `apply`, que este projeto não faz; o `plan` valida a configuração, mas não prova que a política da chave funciona com o DynamoDB.

### 4.7 Sem TTL e sem proteção contra exclusão
Não há dado que expire neste desenho, e o projeto não é implantado. Em produção, eu ligaria a proteção contra exclusão.

## 5. Cognito

### 5.1 Cognito User Pool em vez de um sistema de login próprio
Cadastro, verificação de e-mail, recuperação de senha e emissão de tokens (JWT) são problemas resolvidos e sensíveis a segurança. Com o Cognito eu não guardo senha nem escrevo esse código, e o API Gateway valida o token direto (Fase 3). Abro mão de controle total da experiência de login e fico acoplado ao serviço da AWS.

### 5.2 Login com e-mail, verificado, sem diferenciar maiúsculas
O e-mail é o identificador do cliente. A verificação evita cadastro com e-mail de outra pessoa, e `case_sensitive = false` evita duas contas para `Ana@x.com` e `ana@x.com`.

### 5.3 Senha de 12+ caracteres e MFA por app autenticador, opcional
A política exige maiúscula, minúscula, número e símbolo. O MFA usa TOTP (app autenticador), e não SMS, porque SMS tem custo por mensagem e é mais fraco contra troca de chip. Fica opcional (`OPTIONAL`) para não atrapalhar a compra; em uma loja real, eu exigiria MFA da equipe (grupo `admin`).

### 5.4 App client público, sem segredo, com fluxo SRP
O front-end roda no navegador e não consegue guardar um segredo. O fluxo SRP evita enviar a senha em texto puro, e `prevent_user_existence_errors` impede descobrir quais e-mails estão cadastrados. Tokens de acesso e de identificação duram 60 minutos e o refresh dura 30 dias.

### 5.5 Sem Hosted UI, sem domínio e sem login social por enquanto
O front-end fará o login pela API do Cognito (SDK). Hosted UI e provedores como Google exigiriam domínio e URLs de retorno, e não são necessários para mostrar a arquitetura. É uma evolução possível.

### 5.6 Dois grupos: `clientes` e `admin`
A Lambda da Fase 3 usará o grupo (claim `cognito:groups` no token) para decidir quem altera catálogo e estoque. É autorização simples; o desenho não substitui uma política de permissões mais fina.

### 5.7 Sem recursos de segurança avançada
Detecção de credenciais vazadas e de login suspeito (plano de segurança avançada do Cognito) tem custo adicional e fica fora do escopo de estudo.

## 6. Mudanças em relação ao Seguros Horizonte
| Item | Case 1 | Case 2 |
|---|---|---|
| Chaves KMS | `rds`, `s3` | `dynamodb`, `s3` |
| ViaService | `rds`, `s3` | `dynamodb`, `s3` |
| Buckets | app-data, backups, logs | frontend, logs |
| Criptografia do bucket público | KMS | SSE-S3 |
| Retenção de logs | 2555 dias (7 anos) | 365 dias (padrão) |
| Padrão de `environment` | `prod` | `dev` |
| Módulos networking, ec2, rds | usados | não usados |

## 7. Serviços que não usei
- **RDS/Aurora:** acesso por chave e escala imprevisível combinam com DynamoDB; abro mão de joins e SQL ad hoc.
- **ElastiCache:** DynamoDB já responde em milissegundos; DAX seria a opção se a latência de leitura virasse problema.
- **EC2/ALB/Auto Scaling, ECS/EKS:** sem servidor para manter; abro mão de controle do runtime e aceito cold start.
- **Step Functions e Kinesis:** o fluxo de pedido é simples e SQS/EventBridge bastam.
