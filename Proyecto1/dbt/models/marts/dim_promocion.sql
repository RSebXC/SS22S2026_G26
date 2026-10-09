select id_promocion as promocion_key, p.id_promocion, p.nombre, p.fecha_inicio, p.fecha_fin,
    p.id_categoria, c.nombre as categoria, p.porcentaje_descuento
from {{ ref('stg_promociones') }} p join {{ ref('stg_categoria') }} c using (id_categoria)
