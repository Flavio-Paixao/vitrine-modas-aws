"""Lambda de pedidos: cria o pedido baixando o estoque de forma atômica e consulta pedidos."""
import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

MAX_ITENS = 20


def _dynamodb():
    return boto3.resource("dynamodb")


def _json_default(valor):
    if isinstance(valor, Decimal):
        return int(valor) if valor == valor.to_integral_value() else float(valor)
    raise TypeError(f"Tipo não serializável: {type(valor)}")


def _resposta(status, corpo):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(corpo, default=_json_default, ensure_ascii=False),
    }


def _cliente_id(evento):
    claims = (evento.get("requestContext", {}).get("authorizer") or {}).get("claims") or {}
    return claims.get("sub")


def _validar_itens(corpo):
    itens = corpo.get("itens")
    if not isinstance(itens, list) or not 1 <= len(itens) <= MAX_ITENS:
        raise ValueError(f"Envie de 1 a {MAX_ITENS} itens")
    validos = []
    vistos = set()
    for item in itens:
        produto_id = str(item["produto_id"])
        sku = str(item["sku"])
        quantidade = int(item["quantidade"])
        if quantidade <= 0:
            raise ValueError("quantidade deve ser maior que zero")
        if (produto_id, sku) in vistos:
            raise ValueError("Não repita o mesmo produto/sku; some as quantidades")
        vistos.add((produto_id, sku))
        validos.append({"produto_id": produto_id, "sku": sku, "quantidade": quantidade})
    return validos


def _criar(evento):
    cliente_id = _cliente_id(evento)
    if not cliente_id:
        return _resposta(401, {"erro": "Cliente não identificado"})
    try:
        itens = _validar_itens(json.loads(evento.get("body") or "{}"))
    except (KeyError, TypeError, ValueError, json.JSONDecodeError) as erro:
        return _resposta(400, {"erro": f"Pedido inválido: {erro}"})

    db = _dynamodb()
    produtos = db.Table(os.environ["TABELA_PRODUTOS"])

    # O preço vem SEMPRE do catálogo, nunca do cliente (DECISIONS 6.5)
    total = Decimal("0")
    itens_pedido = []
    for item in itens:
        produto = produtos.get_item(Key={"produto_id": item["produto_id"]}).get("Item")
        if not produto:
            return _resposta(404, {"erro": f"Produto {item['produto_id']} não encontrado"})
        preco = Decimal(str(produto["preco"]))
        total += preco * item["quantidade"]
        itens_pedido.append({**item, "preco_unitario": preco})

    pedido = {
        "pedido_id": str(uuid.uuid4()),
        "cliente_id": cliente_id,
        "criado_em": datetime.now(timezone.utc).isoformat(),
        "status": "CRIADO",
        "itens": itens_pedido,
        "total": total,
    }

    # Uma transação: baixa TODO o estoque e grava o pedido, ou nada acontece (DECISIONS 6.6).
    # O cliente do resource já converte tipos Python para DynamoDB, então os valores vão "puros".
    cliente = db.meta.client
    transacao = [
        {
            "Update": {
                "TableName": os.environ["TABELA_ESTOQUE"],
                "Key": {"produto_id": item["produto_id"], "sku": item["sku"]},
                "UpdateExpression": "SET quantidade = quantidade - :q",
                "ConditionExpression": "attribute_exists(produto_id) AND quantidade >= :q",
                "ExpressionAttributeValues": {":q": item["quantidade"]},
            }
        }
        for item in itens
    ]
    transacao.append(
        {
            "Put": {
                "TableName": os.environ["TABELA_PEDIDOS"],
                "Item": pedido,
                "ConditionExpression": "attribute_not_exists(pedido_id)",
            }
        }
    )
    try:
        cliente.transact_write_items(TransactItems=transacao)
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "TransactionCanceledException":
            return _resposta(409, {"erro": "Estoque insuficiente para um ou mais itens"})
        raise
    return _resposta(201, pedido)


def _listar(evento):
    cliente_id = _cliente_id(evento)
    tabela = _dynamodb().Table(os.environ["TABELA_PEDIDOS"])
    resp = tabela.query(
        IndexName=os.environ["INDICE_CLIENTE"],
        KeyConditionExpression=Key("cliente_id").eq(cliente_id),
        ScanIndexForward=False,
        Limit=50,
    )
    return _resposta(200, {"itens": resp.get("Items", [])})


def _consultar(evento, pedido_id):
    cliente_id = _cliente_id(evento)
    tabela = _dynamodb().Table(os.environ["TABELA_PEDIDOS"])
    item = tabela.get_item(Key={"pedido_id": pedido_id}).get("Item")
    # Pedido de outro cliente responde 404, para não revelar que ele existe
    if not item or item.get("cliente_id") != cliente_id:
        return _resposta(404, {"erro": "Pedido não encontrado"})
    return _resposta(200, item)


def handler(evento, _contexto):
    metodo = evento.get("httpMethod")
    pedido_id = (evento.get("pathParameters") or {}).get("pedido_id")
    if metodo == "POST" and not pedido_id:
        return _criar(evento)
    if metodo == "GET" and not pedido_id:
        return _listar(evento)
    if metodo == "GET" and pedido_id:
        return _consultar(evento, pedido_id)
    return _resposta(405, {"erro": "Método não suportado"})
