"""Lambda do catálogo: lista, consulta e (admin) cadastra produtos."""
import json
import os
from decimal import Decimal, InvalidOperation

import boto3
from boto3.dynamodb.conditions import Key

LIMITE_LISTAGEM = 50


def _tabela():
    return boto3.resource("dynamodb").Table(os.environ["TABELA_PRODUTOS"])


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


def _listar(evento):
    params = evento.get("queryStringParameters") or {}
    categoria = params.get("categoria")
    tabela = _tabela()
    if categoria:
        resp = tabela.query(
            IndexName=os.environ["INDICE_CATEGORIA"],
            KeyConditionExpression=Key("categoria").eq(categoria),
            Limit=LIMITE_LISTAGEM,
        )
    else:
        # Scan limitado: aceitável para um catálogo pequeno de estudo (DECISIONS 6.4)
        resp = tabela.scan(Limit=LIMITE_LISTAGEM)
    return _resposta(200, {"itens": resp.get("Items", [])})


def _consultar(produto_id):
    item = _tabela().get_item(Key={"produto_id": produto_id}).get("Item")
    if not item:
        return _resposta(404, {"erro": "Produto não encontrado"})
    return _resposta(200, item)


def _cadastrar(evento, produto_id):
    if "admin" not in _grupos(evento):
        return _resposta(403, {"erro": "Apenas o grupo admin altera o catálogo"})
    try:
        corpo = json.loads(evento.get("body") or "{}")
        preco = Decimal(str(corpo["preco"]))
        nome = str(corpo["nome"]).strip()
        categoria = str(corpo["categoria"]).strip()
    except (KeyError, ValueError, InvalidOperation, json.JSONDecodeError):
        return _resposta(400, {"erro": "Envie nome, categoria e preco válidos"})
    if preco <= 0 or not nome or not categoria:
        return _resposta(400, {"erro": "nome, categoria e preco devem ser válidos"})
    item = {
        "produto_id": produto_id,
        "nome": nome,
        "categoria": categoria,
        "preco": preco,
        "descricao": str(corpo.get("descricao", "")),
    }
    _tabela().put_item(Item=item)
    return _resposta(200, item)


def handler(evento, _contexto):
    metodo = evento.get("httpMethod")
    produto_id = (evento.get("pathParameters") or {}).get("produto_id")
    if metodo == "GET" and not produto_id:
        return _listar(evento)
    if metodo == "GET":
        return _consultar(produto_id)
    if metodo == "PUT" and produto_id:
        return _cadastrar(evento, produto_id)
    return _resposta(405, {"erro": "Método não suportado"})
