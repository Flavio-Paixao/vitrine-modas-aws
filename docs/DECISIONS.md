# Decisões de arquitetura — Vitrine Modas

Projeto de estudo, validado com `terraform validate` e `terraform plan`. Nada foi implantado (`apply` nunca é executado).

## Sumário
1. Base do projeto
2. KMS
3. S3
4. DynamoDB
5. Cognito
6. Lambdas e API Gateway
7. Mudanças em relação ao Seguros Horizonte
8. Serviços que não usei

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

## 6. Lambdas e API Gateway

### 6.1 Python 3.12 em arm64
Python é a linguagem do case (e a mais pedida em automação na AWS). A arquitetura arm64 (Graviton) costuma custar menos por tempo de execução que x86; abro mão de bibliotecas com binários só para x86, que aqui não existem.

### 6.2 Uma role por função, com mínimo privilégio
`catalogo` lê e escreve só em `produtos`, `estoque` só em `estoque` e `pedidos` só nas três tabelas de que precisa, com os ARNs exatos das tabelas e dos índices. Todas também usam a chave KMS do DynamoDB, porque as tabelas são criptografadas com ela (a key policy só aceita o uso via DynamoDB). Mais roles dão mais trabalho que uma role compartilhada, mas se uma função for comprometida o estrago é menor. Isso melhora o que o Case 1 tinha (uma `lambda_role` genérica, DECISIONS 2.9 do Case 1).

### 6.3 Configuração das funções e skips do checkov
- Sem VPC: as funções só falam com serviços gerenciados pela AWS. Pôr Lambda em VPC traria ENIs e, sem NAT ou endpoints, perda de acesso aos serviços (`CKV_AWS_117`).
- Sem DLQ: a invocação é síncrona, pela API; erro volta para quem chamou (`CKV_AWS_116`).
- Sem concorrência reservada: reservar limitaria o pico da Black Friday (`CKV_AWS_115`).
- Variáveis de ambiente só com nomes de tabelas, sem segredos (`CKV_AWS_173`).
- Sem assinatura de código (`CKV_AWS_272`) e logs sem KMS próprio (`CKV_AWS_158`): ficam como evolução.
- X-Ray ativo nas funções; logs com retenção de 365 dias.

### 6.4 Catálogo com Scan limitado
Listar sem filtro usa `Scan` com limite de 50 itens. Num catálogo pequeno de estudo é aceitável; em escala eu trocaria por um índice com chave fixa de listagem ou por paginação. Abro mão de eficiência por simplicidade.

### 6.5 O preço vem sempre do catálogo
O cliente envia produto, sku e quantidade; o preço é lido de `produtos` dentro da Lambda. Confiar no preço enviado pelo navegador permitiria comprar por qualquer valor.

### 6.6 Pedido e baixa de estoque em uma transação
O pedido usa `TransactWriteItems`: baixa o estoque de todos os itens com `ConditionExpression quantidade >= :q` e grava o pedido, tudo ou nada. Se um item não tem estoque, nada é baixado e a API responde 409. Duas compras do último item não passam as duas. Isso muda o escopo original: em vez de `carrinho/checkout` e `reserva-estoque`, ficam `catalogo`, `estoque` e `pedidos`. O carrinho vive no front-end até o checkout; guardá-lo no servidor exigiria mais uma tabela sem ganho para o estudo. A transação custa mais unidades de escrita que uma escrita simples.

### 6.7 API REST com authorizer do Cognito
O API Gateway valida o token antes de chamar a Lambda, então requisições sem token válido nem chegam nela. A checagem do grupo (`admin`) é feita na Lambda, lendo a claim `cognito:groups`. Escolhi a API REST (e não a HTTP API) porque ela tem authorizer Cognito nativo, limites por método e rastreamento X-Ray. Abro mão do preço menor e da configuração mais simples da HTTP API, que usaria um authorizer JWT.

### 6.8 Rotas públicas, sem CORS e skips do checkov na API
`GET` do catálogo e do estoque são públicos: a vitrine precisa ser navegável sem login (`CKV_AWS_59`). Tudo fica sob `/api`, para o CloudFront servir site e API no mesmo domínio na Fase 5, o que dispensa CORS. Por isso, chamar a API de outro domínio pelo navegador não funciona; para testar, use `curl`. Sem access log (exigiria a role de logs da conta, que é global), sem cache da API (o CloudFront cuida disso) e sem WAF (custo; recomendado em produção). Esses skips (`CKV_AWS_76`, `CKV_AWS_120`, `CKV_AWS_225`, `CKV2_AWS_4`, `CKV2_AWS_29`, `CKV2_AWS_51`, `CKV2_AWS_53`) apontam para esta seção.

### 6.9 Limite de requisições por rota
O stage limita a 100 requisições por segundo, com rajada de 200. Esses valores são configuração de estudo, não medição: protegem as funções e a conta contra abuso, mas podem barrar tráfego legítimo em um pico real e precisariam ser dimensionados com teste de carga.

### 6.10 Testes com moto
As três funções têm testes (`pytest` + `moto`) que simulam o DynamoDB na memória: permissões por grupo, preço vindo do catálogo, estoque nunca negativo e pedidos isolados por cliente. Os testes provam a lógica do código, mas não provam as permissões IAM, a key policy do KMS nem a integração com o API Gateway; isso só um `apply` mostraria, e este projeto não faz `apply`.

## 7. Mudanças em relação ao Seguros Horizonte

| Item | Case 1 | Case 2 |
|---|---|---|
| Chaves KMS | `rds`, `s3` | `dynamodb`, `s3` (+ `messaging` na Fase 4) |
| ViaService | `rds`, `s3` | `dynamodb`, `s3` |
| Buckets | app-data, backups, logs | frontend, logs |
| Criptografia do bucket público | KMS | SSE-S3 |
| Retenção de logs | 2555 dias (7 anos) | 365 dias (padrão) |
| Padrão de `environment` | `prod` | `dev` |
| Role da Lambda | uma genérica, sem função | uma por função, mínimo privilégio |
| CI | fmt, validate, tflint, checkov | + testes Python (pytest com moto) |
| Módulos networking, ec2, rds | usados | não usados |

## 8. Serviços que não usei

- **RDS/Aurora:** acesso por chave e escala imprevisível combinam com DynamoDB; abro mão de joins e SQL ad hoc.
- **ElastiCache:** DynamoDB já responde em milissegundos; DAX seria a opção se a latência de leitura virasse problema.
- **EC2/ALB/Auto Scaling, ECS/EKS:** sem servidor para manter; abro mão de controle do runtime e aceito cold start.
- **Step Functions e Kinesis:** o fluxo de pedido é simples e SQS/EventBridge bastam.
- **HTTP API do API Gateway:** mais barata e simples, mas sem authorizer Cognito nativo nem limites por método (DECISIONS 6.7).
