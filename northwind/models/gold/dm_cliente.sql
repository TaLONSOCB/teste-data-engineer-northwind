-- Dimensão de clientes.
-- Tem um registro por cliente, inclusive os 2 que nunca fizeram pedido.
-- Troquei os nulos por 'Não informado' para esses clientes não sumirem
-- quando alguém filtrar ou agrupar por esses campos em um relatório.
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
