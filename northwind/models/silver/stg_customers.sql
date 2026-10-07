-- Silver de clientes.
-- Tirei os espaços das pontas dos textos e transformei texto vazio em nulo.
-- Os campos opcionais (região, cep, fax) continuam nulos quando não foram
-- preenchidos na origem. O "Não informado" eu só coloco na Gold.
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
