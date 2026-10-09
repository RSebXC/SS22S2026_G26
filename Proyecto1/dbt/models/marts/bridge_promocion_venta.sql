select v.id_detalle as venta_key, p.id_promocion as promocion_key
from {{ ref('int_ventas') }} v
join {{ ref('stg_promociones') }} p on p.id_categoria = v.id_categoria
    and v.fecha between p.fecha_inicio and p.fecha_fin
where v.estado = 'COMPLETADA'
