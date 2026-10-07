-- Silver: produtos.
-- Tipagem: discontinued chega como inteiro 0/1 e vira BOOL;
-- o preco de tabela vira NUMERIC com 2 casas.
with origem as (

    select * from {{ source('bronze', 'raw_products') }}

)

select
    product_id                              as id_produto,
    trim(product_name)                      as nome_produto,
    supplier_id                             as id_fornecedor,
    category_id                             as id_categoria,
    nullif(trim(quantity_per_unit), '')     as quantidade_por_unidade,
    round(cast(unit_price as numeric), 2)   as preco_tabela,
    units_in_stock                          as unidades_em_estoque,
    units_on_order                          as unidades_encomendadas,
    reorder_level                           as nivel_reposicao,
    discontinued = 1                        as descontinuado
from origem
