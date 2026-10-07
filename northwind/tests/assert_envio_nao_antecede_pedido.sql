-- Teste singular: um pedido nao pode ter sido enviado antes de ter sido feito.
select
    id_pedido,
    data_pedido,
    data_envio
from {{ ref('stg_orders') }}
where data_envio < data_pedido
