import json
from decimal import Decimal

from conftest import carregar, evento


def corpo(resposta):
    return json.loads(resposta["body"])


def test_catalogo_cadastro_exige_admin_e_lista_por_categoria(tabelas):
    catalogo = carregar("catalogo")
    novo = {"nome": "Vestido Midi", "categoria": "vestidos", "preco": "199.90"}

    negado = catalogo.handler(evento("PUT", {"produto_id": "p1"}, novo, grupos="clientes"), None)
    assert negado["statusCode"] == 403

    ok = catalogo.handler(evento("PUT", {"produto_id": "p1"}, novo, grupos="[clientes admin]"), None)
    assert ok["statusCode"] == 200

    lista = catalogo.handler(evento("GET", consulta={"categoria": "vestidos"}), None)
    assert lista["statusCode"] == 200
    assert [i["produto_id"] for i in corpo(lista)["itens"]] == ["p1"]

    assert catalogo.handler(evento("GET", {"produto_id": "nao-existe"}), None)["statusCode"] == 404


def test_catalogo_rejeita_preco_invalido(tabelas):
    catalogo = carregar("catalogo")
    ruim = {"nome": "X", "categoria": "y", "preco": "-1"}
    resposta = catalogo.handler(evento("PUT", {"produto_id": "p1"}, ruim, grupos="admin"), None)
    assert resposta["statusCode"] == 400


def test_estoque_reposicao_so_admin(tabelas):
    estoque = carregar("estoque")
    caminho = {"produto_id": "p1", "sku": "p1-M"}

    assert estoque.handler(evento("PUT", caminho, {"quantidade": 5}, grupos="clientes"), None)["statusCode"] == 403
    assert estoque.handler(evento("PUT", caminho, {"quantidade": 5}, grupos="admin"), None)["statusCode"] == 200
    assert estoque.handler(evento("PUT", caminho, {"quantidade": -1}, grupos="admin"), None)["statusCode"] == 400

    consulta = estoque.handler(evento("GET", {"produto_id": "p1"}), None)
    assert corpo(consulta)["itens"][0]["quantidade"] == 5


def _preparar_loja(tabelas, quantidade):
    tabelas.Table("t-produtos").put_item(
        Item={"produto_id": "p1", "nome": "Vestido", "categoria": "vestidos", "preco": Decimal("100.00")}
    )
    tabelas.Table("t-estoque").put_item(Item={"produto_id": "p1", "sku": "p1-M", "quantidade": quantidade})


def test_pedido_baixa_estoque_e_usa_preco_do_catalogo(tabelas):
    _preparar_loja(tabelas, 3)
    pedidos = carregar("pedidos")
    pedido = {"itens": [{"produto_id": "p1", "sku": "p1-M", "quantidade": 2, "preco": 1}]}

    resposta = pedidos.handler(evento("POST", corpo=pedido), None)
    assert resposta["statusCode"] == 201
    assert corpo(resposta)["total"] == 200  # preço do catálogo, não o "1" enviado pelo cliente

    restante = tabelas.Table("t-estoque").get_item(Key={"produto_id": "p1", "sku": "p1-M"})["Item"]
    assert restante["quantidade"] == 1


def test_nao_vende_alem_do_estoque_e_nao_grava_pedido(tabelas):
    _preparar_loja(tabelas, 1)
    pedidos = carregar("pedidos")
    pedido = {"itens": [{"produto_id": "p1", "sku": "p1-M", "quantidade": 1}]}

    primeiro = pedidos.handler(evento("POST", corpo=pedido), None)
    segundo = pedidos.handler(evento("POST", corpo=pedido, sub="cliente-2"), None)

    assert primeiro["statusCode"] == 201
    assert segundo["statusCode"] == 409
    assert tabelas.Table("t-pedidos").scan()["Count"] == 1
    restante = tabelas.Table("t-estoque").get_item(Key={"produto_id": "p1", "sku": "p1-M"})["Item"]
    assert restante["quantidade"] == 0


def test_pedido_com_um_item_sem_estoque_nao_baixa_os_outros(tabelas):
    _preparar_loja(tabelas, 5)
    tabelas.Table("t-estoque").put_item(Item={"produto_id": "p1", "sku": "p1-G", "quantidade": 0})
    pedidos = carregar("pedidos")
    pedido = {
        "itens": [
            {"produto_id": "p1", "sku": "p1-M", "quantidade": 2},
            {"produto_id": "p1", "sku": "p1-G", "quantidade": 1},
        ]
    }
    assert pedidos.handler(evento("POST", corpo=pedido), None)["statusCode"] == 409
    intacto = tabelas.Table("t-estoque").get_item(Key={"produto_id": "p1", "sku": "p1-M"})["Item"]
    assert intacto["quantidade"] == 5  # a transação não baixou nada


def test_cliente_so_ve_os_proprios_pedidos(tabelas):
    _preparar_loja(tabelas, 5)
    pedidos = carregar("pedidos")
    pedido = {"itens": [{"produto_id": "p1", "sku": "p1-M", "quantidade": 1}]}
    criado = corpo(pedidos.handler(evento("POST", corpo=pedido, sub="ana"), None))

    assert pedidos.handler(evento("GET", {"pedido_id": criado["pedido_id"]}, sub="ana"), None)["statusCode"] == 200
    assert pedidos.handler(evento("GET", {"pedido_id": criado["pedido_id"]}, sub="bia"), None)["statusCode"] == 404
    assert len(corpo(pedidos.handler(evento("GET", sub="ana"), None))["itens"]) == 1
    assert corpo(pedidos.handler(evento("GET", sub="bia"), None))["itens"] == []


def test_pedido_invalido(tabelas):
    pedidos = carregar("pedidos")
    assert pedidos.handler(evento("POST", corpo={"itens": []}), None)["statusCode"] == 400
    repetido = {"itens": [{"produto_id": "p", "sku": "s", "quantidade": 1}] * 2}
    assert pedidos.handler(evento("POST", corpo=repetido), None)["statusCode"] == 400
