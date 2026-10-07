-- Teste genérico que eu criei: falha se a combinação de colunas se repetir.
-- Uso para garantir o grão das tabelas que têm chave com mais de uma coluna.
{% test chave_composta_unica(model, colunas) %}

select
    {{ colunas | join(', ') }},
    count(*) as ocorrencias
from {{ model }}
group by {{ colunas | join(', ') }}
having count(*) > 1

{% endtest %}
