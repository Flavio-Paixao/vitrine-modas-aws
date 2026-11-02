import json

import boto3
from boto3.dynamodb.types import TypeSerializer

from conftest import carregar

_serializador = TypeSerializer()


def imagem(item):
    return {k: _serializador.serialize(v) for k, v in item.items()}


def registro(tabela, tipo, antes=None, depois=None):
    dados = {}
    if antes is not None:
        dados["OldImage"] = imagem(antes)
    if depois is not None:
        dados["NewImage"] = imagem(depois)
    return {
        "eventName": tipo,
        "eventSourceARN": f"arn:aws:dynamodb:sa-east-1:123456789012:table/{tabela}/stream/2026-01-01T00:00:00.000",
        "dynamodb": dados,
    }


def test_estoque_baixo_so_quando_cruza_o_limite(monkeypatch):
    monkeypatch.setenv("LIMITE_ESTOQUE_BAIXO", "3")
    publicador = carregar("publicador")
    base = {"produto_id": "p1", "sku": "p1-M"}

    cruzou = publicador.eventos_do_registro(
        registro("t-estoque", "MODIFY", {**base, "quantidade": 4}, {**base, "quantidade": 3})
    )
    assert [e[1] for e in cruzou] == ["EstoqueAlterado", "EstoqueBaixo"]

    ja_baixo = publicador.eventos_do_registro(
        registro("t-estoque", "MODIFY", {**base, "quantidade": 3}, {**base, "quantidade": 2})
    )
    assert [e[1] for e in ja_baixo] == ["EstoqueAlterado"]  # sem alerta repetido


def test_pedido_criado_e_catalogo(monkeypatch):
    publicador = carregar("publicador")
    pedido = {"pedido_id": "x", "cliente_id": "c", "total": 10, "itens": [], "status": "CRIADO"}
    assert [e[1] for e in publicador.eventos_do_registro(registro("t-pedidos", "INSERT", None, pedido))] == [
        "PedidoCriado"
    ]
    # mudança de status do pedido (MODIFY) não gera novo evento: evita laço
    assert publicador.eventos_do_registro(registro("t-pedidos", "MODIFY", pedido, {**pedido, "status": "CONFIRMADO"})) == []

    produto = {"produto_id": "p1", "nome": "Vestido", "categoria": "vestidos", "preco": 10}
    assert publicador.eventos_do_registro(registro("t-produtos", "INSERT", None, produto))[0][1] == "ProdutoAlterado"
    assert publicador.eventos_do_registro(registro("t-produtos", "REMOVE", produto, None))[0][1] == "ProdutoRemovido"


class EventBridgeFalso:
    def __init__(self, falhas=0):
        self.chamadas = []
        self.falhas = falhas

    def put_events(self, Entries):
        self.chamadas.append(Entries)
        return {"FailedEntryCount": self.falhas, "Entries": []}


def test_handler_publica_em_lotes_de_10(monkeypatch):
    monkeypatch.setenv("NOME_BARRAMENTO", "barramento")
    publicador = carregar("publicador")
    falso = EventBridgeFalso()
    monkeypatch.setattr(publicador, "_eventbridge", lambda: falso)
    produto = {"produto_id": "p1", "nome": "V", "categoria": "c", "preco": 10}
    registros = [registro("t-produtos", "INSERT", None, produto)] * 23

    assert publicador.handler({"Records": registros}, None) == {"publicados": 23}
    assert [len(c) for c in falso.chamadas] == [10, 10, 3]
    assert falso.chamadas[0][0]["Source"] == "vitrine.catalogo"
    assert json.loads(falso.chamadas[0][0]["Detail"])["produto_id"] == "p1"


def test_handler_falha_se_o_eventbridge_recusar(monkeypatch):
    import pytest

    monkeypatch.setenv("NOME_BARRAMENTO", "barramento")
    publicador = carregar("publicador")
    monkeypatch.setattr(publicador, "_eventbridge", lambda: EventBridgeFalso(falhas=1))
    produto = {"produto_id": "p1", "nome": "V", "categoria": "c", "preco": 10}
    with pytest.raises(RuntimeError):
        publicador.handler({"Records": [registro("t-produtos", "INSERT", None, produto)]}, None)


def mensagem(pedido_id, id_msg="m1"):
    return {"messageId": id_msg, "body": json.dumps({"detail": {"pedido_id": pedido_id}})}


def test_processador_confirma_uma_vez_e_ignora_repeticao(tabelas):
    tabelas.Table("t-pedidos").put_item(Item={"pedido_id": "x", "cliente_id": "c", "criado_em": "2026", "status": "CRIADO"})
    processador = carregar("processador")

    assert processador.handler({"Records": [mensagem("x")]}, None) == {"batchItemFailures": []}
    assert tabelas.Table("t-pedidos").get_item(Key={"pedido_id": "x"})["Item"]["status"] == "CONFIRMADO"
    # mensagem repetida: continua sem falha
    assert processador.handler({"Records": [mensagem("x")]}, None) == {"batchItemFailures": []}


def test_processador_devolve_so_a_mensagem_com_erro(tabelas):
    tabelas.Table("t-pedidos").put_item(Item={"pedido_id": "x", "cliente_id": "c", "criado_em": "2026", "status": "CRIADO"})
    processador = carregar("processador")
    mensagens = [mensagem("x", "ok"), {"messageId": "quebrada", "body": "isto não é json"}]

    resposta = processador.handler({"Records": mensagens}, None)
    assert resposta == {"batchItemFailures": [{"itemIdentifier": "quebrada"}]}
