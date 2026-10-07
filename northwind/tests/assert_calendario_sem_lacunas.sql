-- A dm_calendario tem que ter exatamente um registro por dia,
-- sem dia faltando entre a menor e a maior data.
with resumo as (

    select
        count(*)                                  as dias_existentes,
        date_diff(max(data), min(data), day) + 1  as dias_esperados
    from {{ ref('dm_calendario') }}

)

select *
from resumo
where dias_existentes != dias_esperados
