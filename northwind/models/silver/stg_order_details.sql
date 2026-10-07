-- Silver dos itens dos pedidos.
-- O preço e o desconto vêm como REAL do PostgreSQL (ponto flutuante).
-- Converti para NUMERIC e arredondei, para não dar diferença de centavos
-- nos cálculos de valor que são feitos na Gold.
with origem as (

    select * from {{ source('bronze', 'raw_order_details') }}

)

select
    order_id                                as id_pedido,
    product_id                              as id_produto,
    round(cast(unit_price as numeric), 2)   as preco_unitario,
    cast(quantity as int64)                 as quantidade,
    round(cast(discount as numeric), 4)     as percentual_desconto
from origem
