"""Lê os streams do DynamoDB e publica eventos de negócio no EventBridge."""
import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.types import TypeDeserializer

_deserializador = TypeDeserializer()
LOTE_EVENTBRIDGE = 10  # limite do PutEvents por chamada


def _eventbridge():
    return boto3.client("events")


def _json_default(valor):
    if isinstance(valor, Decimal):
        return int(valor) if valor == valor.to_integral_value() else float(valor)
    raise TypeError(f"Tipo não serializável: {type(valor)}")


def _item(imagem):
    return {k: _deserializador.deserialize(v) for k, v in (imagem or {}).items()}


def _tabela_do_registro(registro):
    origem = registro.get("eventSourceARN", "")
    for chave, variavel in (
        ("produtos", "TABELA_PRODUTOS"),
        ("estoque", "TABELA_ESTOQUE"),
        ("pedidos", "TABELA_PEDIDOS"),
    ):
        if f"table/{os.environ[variavel]}/stream" in origem:
            return chave
    return None


def _limite_estoque_baixo():
    return int(os.environ.get("LIMITE_ESTOQUE_BAIXO", "3"))


def eventos_do_registro(registro):
    """Transforma um registro de stream em zero ou mais eventos (fonte, tipo, detalhe)."""
    tabela = _tabela_do_registro(registro)
    tipo = registro["eventName"]  # INSERT, MODIFY ou REMOVE
    dados = registro["dynamodb"]
    antes = _item(dados.get("OldImage"))
    depois = _item(dados.get("NewImage"))
    eventos = []

    if tabela == "produtos":
        if tipo == "REMOVE":
            eventos.append(("vitrine.catalogo", "ProdutoRemovido", {"produto_id": antes.get("produto_id")}))
        else:
            eventos.append(
                (
                    "vitrine.catalogo",
                    "ProdutoAlterado",
                    {"produto_id": depois["produto_id"], "operacao": tipo, "antes": antes, "depois": depois},
                )
            )
    elif tabela == "estoque" and tipo != "REMOVE":
        qtd_antes = antes.get("quantidade")
        qtd_depois = depois.get("quantidade")
        base = {"produto_id": depois["produto_id"], "sku": depois["sku"]}
        eventos.append(
            ("vitrine.estoque", "EstoqueAlterado", {**base, "quantidade_antes": qtd_antes, "quantidade_depois": qtd_depois})
        )
        limite = _limite_estoque_baixo()
        # Só avisa quando CRUZA o limite, para não repetir o alerta a cada venda
        if qtd_depois is not None and qtd_depois <= limite and (qtd_antes is None or qtd_antes > limite):
            eventos.append(("vitrine.estoque", "EstoqueBaixo", {**base, "quantidade": qtd_depois, "limite": limite}))
    elif tabela == "pedidos" and tipo == "INSERT":
        eventos.append(
            (
                "vitrine.pedidos",
                "PedidoCriado",
                {
                    "pedido_id": depois["pedido_id"],
                    "cliente_id": depois["cliente_id"],
                    "total": depois["total"],
                    "itens": depois["itens"],
                },
            )
        )
    return eventos


def handler(evento, _contexto):
    barramento = os.environ["NOME_BARRAMENTO"]
    entradas = []
    for registro in evento.get("Records", []):
        for fonte, tipo, detalhe in eventos_do_registro(registro):
            entradas.append(
                {
                    "EventBusName": barramento,
                    "Source": fonte,
                    "DetailType": tipo,
                    "Detail": json.dumps(detalhe, default=_json_default, ensure_ascii=False),
                }
            )

    cliente = _eventbridge()
    for i in range(0, len(entradas), LOTE_EVENTBRIDGE):
        resposta = cliente.put_events(Entries=entradas[i : i + LOTE_EVENTBRIDGE])
        if resposta.get("FailedEntryCount", 0):
            # Falhar faz o Lambda repetir o lote (e dividi-lo ao meio, se configurado)
            raise RuntimeError(f"{resposta['FailedEntryCount']} evento(s) não publicados")
    return {"publicados": len(entradas)}
