select resultado_validacion, count(*) as registros, sum(cantidad) as unidades
from {{ ref('fact_devoluciones') }} group by resultado_validacion
