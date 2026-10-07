-- A fato não pode perder nem duplicar item em relação à Bronze.
-- Comparo a quantidade de linhas e o valor bruto total da ft_vendas com o que
-- foi carregado na raw_order_details. Se der diferença o teste falha.
with fato as (

    select
        count(*)         as linhas_fato,
        sum(valor_bruto) as valor_bruto_fato
    from {{ ref('ft_vendas') }}

),

bronze as (

    select
        count(*)                                             as linhas_bronze,
        round(sum(cast(unit_price as numeric) * quantity), 2) as valor_bruto_bronze
    from {{ source('bronze', 'raw_order_details') }}

)

select *
from fato
cross join bronze
where linhas_fato != linhas_bronze
   or abs(valor_bruto_fato - valor_bruto_bronze) > 0.01
