import importlib.util
import os
import sys
from pathlib import Path

import boto3
import pytest
from moto import mock_aws

RAIZ = Path(__file__).resolve().parent.parent


def carregar(nome):
    """Importa src/lambdas/<nome>/app.py com um nome único (todos se chamam app.py)."""
    caminho = RAIZ / "src" / "lambdas" / nome / "app.py"
    spec = importlib.util.spec_from_file_location(f"lambda_{nome}", caminho)
    modulo = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = modulo
    spec.loader.exec_module(modulo)
    return modulo


@pytest.fixture(autouse=True)
def ambiente(monkeypatch):
    for chave in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_SESSION_TOKEN"):
        monkeypatch.setenv(chave, "teste")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "sa-east-1")
    monkeypatch.setenv("TABELA_PRODUTOS", "t-produtos")
    monkeypatch.setenv("TABELA_ESTOQUE", "t-estoque")
    monkeypatch.setenv("TABELA_PEDIDOS", "t-pedidos")
    monkeypatch.setenv("INDICE_CATEGORIA", "categoria-index")
    monkeypatch.setenv("INDICE_CLIENTE", "cliente-index")


@pytest.fixture
def tabelas():
    """Cria as três tabelas com o mesmo desenho do módulo Terraform `dynamodb`."""
    with mock_aws():
        db = boto3.resource("dynamodb", region_name="sa-east-1")
        db.create_table(
            TableName="t-produtos",
            BillingMode="PAY_PER_REQUEST",
            KeySchema=[{"AttributeName": "produto_id", "KeyType": "HASH"}],
            AttributeDefinitions=[
                {"AttributeName": "produto_id", "AttributeType": "S"},
                {"AttributeName": "categoria", "AttributeType": "S"},
                {"AttributeName": "nome", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "categoria-index",
                    "KeySchema": [
                        {"AttributeName": "categoria", "KeyType": "HASH"},
                        {"AttributeName": "nome", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                }
            ],
        )
        db.create_table(
            TableName="t-estoque",
            BillingMode="PAY_PER_REQUEST",
            KeySchema=[
                {"AttributeName": "produto_id", "KeyType": "HASH"},
                {"AttributeName": "sku", "KeyType": "RANGE"},
            ],
            AttributeDefinitions=[
                {"AttributeName": "produto_id", "AttributeType": "S"},
                {"AttributeName": "sku", "AttributeType": "S"},
            ],
        )
        db.create_table(
            TableName="t-pedidos",
            BillingMode="PAY_PER_REQUEST",
            KeySchema=[{"AttributeName": "pedido_id", "KeyType": "HASH"}],
            AttributeDefinitions=[
                {"AttributeName": "pedido_id", "AttributeType": "S"},
                {"AttributeName": "cliente_id", "AttributeType": "S"},
                {"AttributeName": "criado_em", "AttributeType": "S"},
            ],
            GlobalSecondaryIndexes=[
                {
                    "IndexName": "cliente-index",
                    "KeySchema": [
                        {"AttributeName": "cliente_id", "KeyType": "HASH"},
                        {"AttributeName": "criado_em", "KeyType": "RANGE"},
                    ],
                    "Projection": {"ProjectionType": "ALL"},
                }
            ],
        )
        yield db


def evento(metodo, caminho=None, corpo=None, consulta=None, grupos="", sub="cliente-1"):
    import json

    claims = {"sub": sub}
    if grupos:
        claims["cognito:groups"] = grupos
    return {
        "httpMethod": metodo,
        "pathParameters": caminho,
        "queryStringParameters": consulta,
        "body": json.dumps(corpo) if corpo is not None else None,
        "requestContext": {"authorizer": {"claims": claims}},
    }
