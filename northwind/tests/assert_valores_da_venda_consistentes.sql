-- Teste singular: coerencia das metricas da fato.
-- valor_liquido = valor_bruto - valor_desconto, e o desconto nunca supera o bruto.
select
    id_venda,
    valor_bruto,
    valor_desconto,
    valor_liquido
from {{ ref('ft_vendas') }}
where valor_liquido != valor_bruto - valor_desconto
   or valor_desconto > valor_bruto
   or valor_liquido < 0
