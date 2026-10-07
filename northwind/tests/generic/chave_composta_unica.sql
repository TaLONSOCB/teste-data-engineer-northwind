-- Teste generico customizado: falha se a combinacao de colunas se repetir.
-- Garante o grao de tabelas cuja chave tem mais de uma coluna.
{% test chave_composta_unica(model, colunas) %}

select
    {{ colunas | join(', ') }},
    count(*) as ocorrencias
from {{ model }}
group by {{ colunas | join(', ') }}
having count(*) > 1

{% endtest %}
