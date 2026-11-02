"""Lambda do estoque: consulta a disponibilidade e (admin) repõe quantidades."""
import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


def _tabela():
    return boto3.resource("dynamodb").Table(os.environ["TABELA_ESTOQUE"])


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


def _grupos(evento):
    claims = (evento.get("requestContext", {}).get("authorizer") or {}).get("claims") or {}
    bruto = claims.get("cognito:groups", "")
    if isinstance(bruto, list):
        return set(bruto)
    return {g for g in str(bruto).strip("[]").replace(",", " ").split() if g}


def _consultar(produto_id):
    resp = _tabela().query(KeyConditionExpression=Key("produto_id").eq(produto_id))
    return _resposta(200, {"itens": resp.get("Items", [])})


def _repor(evento, produto_id, sku):
    if "admin" not in _grupos(evento):
        return _resposta(403, {"erro": "Apenas o grupo admin altera o estoque"})
    try:
        quantidade = int(json.loads(evento.get("body") or "{}")["quantidade"])
    except (KeyError, ValueError, TypeError, json.JSONDecodeError):
        return _resposta(400, {"erro": "Envie quantidade inteira"})
    if quantidade < 0:
        return _resposta(400, {"erro": "quantidade não pode ser negativa"})
    _tabela().update_item(
        Key={"produto_id": produto_id, "sku": sku},
        UpdateExpression="SET quantidade = :q",
        ExpressionAttributeValues={":q": quantidade},
    )
    return _resposta(200, {"produto_id": produto_id, "sku": sku, "quantidade": quantidade})


def handler(evento, _contexto):
    metodo = evento.get("httpMethod")
    caminho = evento.get("pathParameters") or {}
    produto_id = caminho.get("produto_id")
    sku = caminho.get("sku")
    if metodo == "GET" and produto_id:
        return _consultar(produto_id)
    if metodo == "PUT" and produto_id and sku:
        return _repor(evento, produto_id, sku)
    return _resposta(405, {"erro": "Método não suportado"})
