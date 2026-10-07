-- Silver do cabeçalho dos pedidos.
-- As datas chegam como DATETIME na Bronze (sempre com hora 00:00:00), então
-- converti para DATE. O frete eu converti para NUMERIC com 2 casas.
-- Os pedidos que ainda não foram enviados ficam com data_envio nula, e criei
-- a coluna pedido_enviado para deixar isso claro em vez de esconder o nulo.
with origem as (

    select * from {{ source('bronze', 'raw_orders') }}

)

select
    order_id                                as id_pedido,
    upper(trim(customer_id))                as id_cliente,
    employee_id                             as id_funcionario,
    cast(order_date as date)                as data_pedido,
    cast(required_date as date)             as data_prazo_entrega,
    cast(shipped_date as date)              as data_envio,
    shipped_date is not null                as pedido_enviado,
    ship_via                                as id_transportadora,
    round(cast(freight as numeric), 2)      as valor_frete,
    nullif(trim(ship_name), '')             as nome_destinatario,
    nullif(trim(ship_address), '')          as endereco_entrega,
    nullif(trim(ship_city), '')             as cidade_entrega,
    nullif(trim(ship_region), '')           as regiao_entrega,
    nullif(trim(ship_postal_code), '')      as cep_entrega,
    nullif(trim(ship_country), '')          as pais_entrega
from origem
