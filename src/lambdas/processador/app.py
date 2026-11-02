"""Consome a fila de pedidos: confirma cada pedido criado (de forma idempotente)."""
import json
import os

import boto3
from botocore.exceptions import ClientError


def _tabela():
    return boto3.resource("dynamodb").Table(os.environ["TABELA_PEDIDOS"])


def _confirmar(pedido_id):
    try:
        _tabela().update_item(
            Key={"pedido_id": pedido_id},
            UpdateExpression="SET #s = :confirmado",
            ConditionExpression="attribute_exists(pedido_id) AND #s = :criado",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":confirmado": "CONFIRMADO", ":criado": "CRIADO"},
        )
    except ClientError as erro:
        # Já confirmado (mensagem repetida) ou inexistente: não é erro de processamento
        if erro.response["Error"]["Code"] != "ConditionalCheckFailedException":
            raise


def handler(evento, _contexto):
    falhas = []
    for mensagem in evento.get("Records", []):
        try:
            corpo = json.loads(mensagem["body"])
            _confirmar(corpo["detail"]["pedido_id"])
        except Exception:  # noqa: BLE001 - qualquer erro devolve só esta mensagem à fila
            falhas.append({"itemIdentifier": mensagem["messageId"]})
    # Só as mensagens que falharam voltam; depois de 3 tentativas vão para a DLQ
    return {"batchItemFailures": falhas}
