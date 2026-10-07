-- Gold: fato de vendas.
-- Grao: um registro por item de pedido (produto dentro de um pedido).
-- Chaves: cliente, produto e data do pedido (liga na dm_calendario).
-- Metricas:
--   valor_bruto    = preco_unitario * quantidade
--   valor_desconto = valor_bruto * percentual_desconto (arredondado a centavos)
--   valor_liquido  = valor_bruto - valor_desconto
-- O frete fica fora da fato porque pertence ao pedido, nao ao item: traze-lo
-- para este grao duplicaria o valor a cada item.
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
