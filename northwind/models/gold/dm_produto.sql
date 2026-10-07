-- Dimensão de produtos.
-- Um registro por produto. Criei a coluna situacao (Ativo/Descontinuado)
-- a partir do booleano, para ficar mais fácil de usar em relatório.
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
