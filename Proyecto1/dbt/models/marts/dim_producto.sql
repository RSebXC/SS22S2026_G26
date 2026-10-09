select p.id_producto as producto_key, p.id_producto, p.sku, p.nombre, p.id_categoria, p.id_marca,
    p.unidad_medida, p.costo_base, p.precio_lista, p.activo, c.nombre as categoria, m.nombre as marca
from {{ ref('stg_producto') }} p
join {{ ref('stg_categoria') }} c using (id_categoria)
join {{ ref('stg_marca') }} m using (id_marca)
