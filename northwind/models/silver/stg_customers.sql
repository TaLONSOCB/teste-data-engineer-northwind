-- Silver: clientes.
-- Limpeza: remove espacos nas pontas e converte texto vazio em NULL.
-- Campos opcionais (regiao, cep, fax) permanecem NULL quando nao informados:
-- a Silver nao inventa valores; o rotulo "Nao informado" e aplicado na Gold.
with origem as (

    select * from {{ source('bronze', 'raw_customers') }}

)

select
    upper(trim(customer_id))            as id_cliente,
    trim(company_name)                  as nome_empresa,
    nullif(trim(contact_name), '')      as nome_contato,
    nullif(trim(contact_title), '')     as cargo_contato,
    nullif(trim(address), '')           as endereco,
    nullif(trim(city), '')              as cidade,
    nullif(trim(region), '')            as regiao,
    nullif(trim(postal_code), '')       as cep,
    nullif(trim(country), '')           as pais,
    nullif(trim(phone), '')             as telefone,
    nullif(trim(fax), '')               as fax
from origem
