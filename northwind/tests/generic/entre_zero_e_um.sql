-- Teste genérico que eu criei: falha se a coluna sair do intervalo de 0 a 1.
-- Uso no percentual de desconto, que vem como fração.
{% test entre_zero_e_um(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} < 0 or {{ column_name }} > 1

{% endtest %}
