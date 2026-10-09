-- Detectar referencias huérfanas antes de que un join pueda descartar filas.
select 'venta_cliente' as tipo, v.id_venta::text as identificador
from {{ ref('stg_venta') }} v left join {{ ref('stg_cliente') }} c using (id_cliente)
where c.id_cliente is null
union all
select 'venta_sucursal',v.id_venta::text
from {{ ref('stg_venta') }} v left join {{ ref('stg_sucursal') }} s using (id_sucursal)
where s.id_sucursal is null
union all
select 'detalle_venta',d.id_detalle::text
from {{ ref('stg_venta_detalle') }} d left join {{ ref('stg_venta') }} v using (id_venta)
where v.id_venta is null
union all
select 'detalle_producto',d.id_detalle::text
from {{ ref('stg_venta_detalle') }} d left join {{ ref('stg_producto') }} p using (id_producto)
where p.id_producto is null
union all
select 'producto_categoria',p.id_producto::text
from {{ ref('stg_producto') }} p left join {{ ref('stg_categoria') }} c using (id_categoria)
where c.id_categoria is null
union all
select 'producto_marca',p.id_producto::text
from {{ ref('stg_producto') }} p left join {{ ref('stg_marca') }} m using (id_marca)
where m.id_marca is null
union all
select 'promocion_categoria',p.id_promocion::text
from {{ ref('stg_promociones') }} p left join {{ ref('stg_categoria') }} c using (id_categoria)
where c.id_categoria is null
