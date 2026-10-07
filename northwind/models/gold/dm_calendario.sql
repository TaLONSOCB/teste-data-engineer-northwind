-- Dimensão de calendário, gerada aqui no dbt porque não existe na origem.
-- Um registro por dia. Peguei os anos completos entre o primeiro e o último
-- pedido, para as análises por ano e por trimestre não ficarem cortadas.
with limites as (

    select
        date_trunc(min(data_pedido), year)  as data_inicial,
        last_day(max(data_pedido), year)    as data_final
    from {{ ref('stg_orders') }}

),

dias as (

    select data
    from limites,
         unnest(generate_date_array(data_inicial, data_final)) as data

)

select
    data,
    extract(year from data)       as ano,
    extract(quarter from data)    as trimestre,
    extract(month from data)      as mes,
    ['Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho',
     'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
    ][offset(extract(month from data) - 1)]            as nome_mes,
    extract(dayofweek from data)  as dia_semana,
    ['Domingo', 'Segunda-feira', 'Terça-feira', 'Quarta-feira',
     'Quinta-feira', 'Sexta-feira', 'Sábado'
    ][offset(extract(dayofweek from data) - 1)]        as nome_dia_semana,
    extract(dayofweek from data) in (1, 7)             as fim_de_semana
from dias
