with ventas as (
    select f.periodo, v.sucursal_key, count(distinct v.id_venta) filter (where v.estado='COMPLETADA') as tickets,
        sum(v.importe_neto_vendido) as ventas_completadas, sum(v.unidades_vendidas) as unidades_vendidas,
        sum(v.margen_estimado) as margen_estimado
    from {{ ref('fact_ventas') }} v join {{ ref('dim_fecha') }} f using (fecha_key)
    group by f.periodo, v.sucursal_key
), devoluciones as (
    select f.periodo, d.sucursal_key, sum(d.importe_devolucion_estimado) as devoluciones_estimadas
    from {{ ref('fact_devoluciones') }} d join {{ ref('dim_fecha') }} f using (fecha_key)
    group by f.periodo, d.sucursal_key
), metas as (select * from {{ ref('fact_metas') }}), claves as (
    select periodo,sucursal_key from ventas union select periodo,sucursal_key from metas
    union select periodo,sucursal_key from devoluciones
)
select k.periodo, k.sucursal_key, s.nombre as sucursal,
    coalesce(v.tickets,0) as tickets, coalesce(v.ventas_completadas,0) as ventas_completadas,
    coalesce(v.unidades_vendidas,0) as unidades_vendidas,
    coalesce(v.margen_estimado,0) as margen_estimado,
    coalesce(d.devoluciones_estimadas,0) as devoluciones_estimadas,
    coalesce(v.ventas_completadas,0)-coalesce(d.devoluciones_estimadas,0) as ventas_ajustadas_estimadas,
    m.meta_ventas, m.meta_unidades,
    coalesce(v.ventas_completadas,0)/nullif(m.meta_ventas,0) as cumplimiento_meta,
    coalesce(v.ventas_completadas,0)/nullif(v.tickets,0) as ticket_promedio
from claves k join {{ ref('dim_sucursal') }} s using (sucursal_key)
left join ventas v using (periodo,sucursal_key)
left join devoluciones d using (periodo,sucursal_key)
left join metas m using (periodo,sucursal_key)
