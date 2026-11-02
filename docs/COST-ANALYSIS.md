# Análise de custo — Vitrine Modas

**Este projeto não foi implantado, então o custo real é zero e não existe nenhum número medido.** Este documento mostra **como estimar** o custo do desenho, serviço por serviço, e quais perguntas de negócio mudam a conta. Os preços unitários não estão aqui de propósito: mudam com o tempo e com a região. Para fechar a estimativa, preencha a coluna "Preço unitário" com os valores atuais da região `sa-east-1` no [AWS Pricing Calculator](https://calculator.aws/) e use as fórmulas abaixo.

## Como usar
1. Escolha uma **hipótese de uso** (cenário) e escreva os números nas variáveis da tabela 1.
2. Para cada serviço, aplique a fórmula da tabela 2 com o preço unitário atual.
3. Some. Registre sempre o cenário junto com o resultado ("com X pedidos por mês, estimativa de Y"). Nunca cite o total sem o cenário.

## 1. Hipóteses de uso (você define; os valores abaixo são exemplos em branco)

| Variável | Significado | Cenário baixo | Cenário pico (Black Friday) |
|---|---|---|---|
| `V` | visitantes por mês | _preencher_ | _preencher_ |
| `R` | requisições à API por visita | _preencher_ | _preencher_ |
| `P` | pedidos por mês | _preencher_ | _preencher_ |
| `I` | itens por pedido | _preencher_ | _preencher_ |
| `GB_site` | dados servidos pelo CloudFront por mês (GB) | _preencher_ | _preencher_ |
| `GB_dados` | dados armazenados no DynamoDB (GB) | _preencher_ | _preencher_ |
| `U` | usuários ativos por mês no Cognito | _preencher_ | _preencher_ |

## 2. Fatores de custo por serviço

| Serviço | Como a AWS cobra | Fórmula de estimativa | Preço unitário |
|---|---|---|---|
| CloudFront | dados transferidos e requisições | `GB_site × preço/GB + V×(R+1) × preço/requisição` | _preencher_ |
| S3 (front-end e logs) | armazenamento e requisições | `GB armazenados × preço/GB` (pequeno) | _preencher_ |
| API Gateway (REST) | por milhão de requisições | `V × R / 1.000.000 × preço` | _preencher_ |
| Lambda | requisições e GB-segundo (tempo × memória) | `chamadas × preço/chamada + chamadas × duração(s) × 0,25 GB × preço/GB-s` (memória configurada: 256 MB) | _preencher_ |
| DynamoDB (sob demanda) | unidades de leitura e de escrita, armazenamento, PITR, Streams | `escritas × preço + leituras × preço + GB_dados × preço/GB`; cada pedido faz escrita por item mais a escrita do pedido (transação custa o dobro de uma escrita simples) | _preencher_ |
| Cognito | por usuário ativo no mês (com faixa gratuita) | `U × preço/MAU` acima da faixa gratuita | _preencher_ |
| EventBridge | por evento publicado | `eventos × preço` | _preencher_ |
| SQS | por requisição | `(P × alguns envios/recebimentos) × preço` | _preencher_ |
| SNS | por publicação (e por entrega por e-mail) | `alertas × preço` (pequeno) | _preencher_ |
| KMS | **mensalidade por chave** + por requisição | `3 chaves × mensalidade + requisições × preço` (custo fixo, existe sem tráfego) | _preencher_ |
| CloudWatch | alarmes (cada um), dashboard, logs ingeridos e armazenados, métricas detalhadas | `7 alarmes × preço + GB de logs × preço` | _preencher_ |
| X-Ray | por traço gravado e recuperado | `traços × preço` (a amostragem limita) | _preencher_ |
| AWS Budgets | gratuito para poucos orçamentos | confirmar na página de preços | _preencher_ |

## 3. O que é custo fixo e o que é variável
- **Fixo, mesmo sem nenhuma visita:** mensalidade das 3 chaves KMS, alarmes e dashboard do CloudWatch, armazenamento mínimo (S3, DynamoDB, logs) e PITR.
- **Variável com o tráfego:** CloudFront, API Gateway, Lambda, DynamoDB (leituras e escritas), filas, eventos e traços.
- Por isso, o desenho sob demanda é bom para tráfego irregular (paga-se pouco fora do pico), mas **não é necessariamente o mais barato** em carga alta e constante, onde capacidade provisionada ou outro modelo pode compensar (DECISIONS 4.1).

## 4. Decisões que mexem na conta
| Decisão | Efeito no custo |
|---|---|
| DynamoDB sob demanda (4.1) | sem capacidade ociosa, mas preço por requisição maior que provisionado em carga constante |
| Transação no pedido (6.6) | cada item custa mais unidades de escrita que uma escrita simples |
| `PriceClass_All` no CloudFront (8.5) | inclui pontos na América do Sul, com preço por GB maior que as classes baratas |
| API REST e não HTTP API (6.7) | a HTTP API costuma ser mais barata por requisição |
| Logs com retenção de 365 dias (6.3) | armazenamento de logs cresce com o tempo |
| Rastreamento X-Ray com amostragem (9.3) | amostrar limita o número de traços cobrados |
| 3 chaves KMS (2.1, 7.4) | mensalidade fixa por chave: mais isolamento, mais custo fixo |
| Sem WAF (8.4) | evita o custo, mas é uma proteção a considerar em produção |

## 5. Como controlar o gasto (se um dia for implantado)
- AWS Budgets com aviso em 80% do gasto e 100% da previsão (definido no código e não implantado, DECISIONS 9.4). Ele avisa, mas não bloqueia.
- Limites de requisição por rota na API (já configurados, DECISIONS 6.9).
- Tag `Project` em todos os recursos (já aplicada em `default_tags`); ativá-la como tag de alocação de custos permitiria filtrar o orçamento por projeto.
- Destruir o ambiente de teste quando não estiver em uso (`terraform destroy`, só em um ambiente de estudo seu e com a sua decisão).

## 6. O que dizer em entrevista
"Projeto de estudo, não implantado: eu estimei custo por serviço, com hipóteses explícitas de uso, e identifiquei quais decisões de arquitetura pesam mais na conta (sob demanda, transações, classe de preço do CloudFront). Não tenho número de custo real."
