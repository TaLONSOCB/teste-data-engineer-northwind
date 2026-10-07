-- Silver: itens dos pedidos.
-- Tipagem: preco e desconto vem do tipo REAL do PostgreSQL (ponto flutuante).
-- Sao convertidos para NUMERIC e arredondados para evitar erro de
-- arredondamento nos calculos de valor da camada Gold.
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
