-- Teste generico customizado: falha se a coluna tiver valor negativo.
{% test nao_negativo(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
