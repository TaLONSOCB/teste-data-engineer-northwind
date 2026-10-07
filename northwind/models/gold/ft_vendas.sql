-- Fato de vendas.
-- Grão: um registro por item de pedido (um produto dentro de um pedido).
-- Chaves: cliente, produto e data do pedido (que liga na dm_calendario).
-- Métricas:
--   valor_bruto    = preco_unitario * quantidade
--   valor_desconto = valor_bruto * percentual_desconto (arredondado em centavos)
--   valor_liquido  = valor_bruto - valor_desconto
-- Não trouxe o frete para cá porque ele é do pedido e não do item. Nesse
-- grão ele ia se repetir em cada item e a soma ficaria errada.
with itens as (

    select * from {{ ref('stg_order_details') }}

),

pedidos as (

    select * from {{ ref('stg_orders') }}

),

base as (

    select
        concat(cast(itens.id_pedido as string), '-', cast(itens.id_produto as string)) as id_venda,
        itens.id_pedido,
        itens.id_produto,
        pedidos.id_cliente,
        pedidos.data_pedido,
        itens.quantidade,
        itens.preco_unitario,
        itens.percentual_desconto,
        round(itens.preco_unitario * itens.quantidade, 2) as valor_bruto
    from itens
    inner join pedidos
        on pedidos.id_pedido = itens.id_pedido

)

select
    id_venda,
    id_pedido,
    id_produto,
    id_cliente,
    data_pedido,
    quantidade,
    preco_unitario,
    percentual_desconto,
    valor_bruto,
    round(valor_bruto * percentual_desconto, 2)                as valor_desconto,
    valor_bruto - round(valor_bruto * percentual_desconto, 2)  as valor_liquido
from base
