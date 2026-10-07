-- Teste singular: a fato nao pode perder nem duplicar itens em relacao a Bronze.
-- Compara a quantidade de linhas e o valor bruto total da ft_vendas com o que
-- foi ingerido em raw_order_details. Retorna linha (falha) se houver diferenca.
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
