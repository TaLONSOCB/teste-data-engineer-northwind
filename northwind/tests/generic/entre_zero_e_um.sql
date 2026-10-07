-- Teste generico customizado: falha se a coluna sair do intervalo [0, 1].
-- Usado para percentuais expressos como fracao.
{% test entre_zero_e_um(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0 or {{ column_name }} > 1

{% endtest %}
