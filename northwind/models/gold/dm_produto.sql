-- Gold: dimensao de produtos.
-- Um registro por produto. A situacao (Ativo/Descontinuado) e derivada do
-- indicador booleano para facilitar o uso em relatorios.
select
    id_produto,
    nome_produto,
    id_categoria,
    id_fornecedor,
    coalesce(quantidade_por_unidade, 'Não informado')  as quantidade_por_unidade,
    preco_tabela,
    descontinuado,
    case when descontinuado then 'Descontinuado' else 'Ativo' end as situacao
from {{ ref('stg_products') }}
