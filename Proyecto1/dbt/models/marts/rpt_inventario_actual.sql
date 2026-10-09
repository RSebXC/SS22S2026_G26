select i.*, p.nombre as producto, p.categoria, p.marca,
    s.nombre as sucursal, f.fecha as fecha_corte
from {{ ref('fact_inventario') }} i
join {{ ref('dim_producto') }} p using (producto_key)
join {{ ref('dim_sucursal') }} s using (sucursal_key)
join {{ ref('dim_fecha') }} f using (fecha_key)
where i.fecha_key = (select max(fecha_key) from {{ ref('fact_inventario') }})
