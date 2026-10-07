-- Gold: dimensao de clientes.
-- Um registro por cliente, incluindo os que ainda nao compraram (2 na base).
-- Atributos descritivos nulos recebem o rotulo 'Nao informado' para que
-- filtros e agrupamentos nas ferramentas de analise nao escondam registros.
select
    id_cliente,
    nome_empresa,
    coalesce(nome_contato, 'Não informado')   as nome_contato,
    coalesce(cargo_contato, 'Não informado')  as cargo_contato,
    coalesce(cidade, 'Não informado')         as cidade,
    coalesce(regiao, 'Não informado')         as regiao,
    coalesce(cep, 'Não informado')            as cep,
    coalesce(pais, 'Não informado')           as pais
from {{ ref('stg_customers') }}
