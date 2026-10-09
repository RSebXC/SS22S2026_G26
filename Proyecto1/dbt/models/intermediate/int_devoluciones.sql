with devoluciones as (
    select *, sum(cantidad) over (partition by id_venta, id_producto) as cantidad_total_devuelta
    from {{ ref('stg_devoluciones') }}
)
select d.*, v.id_detalle, v.id_cliente, v.id_sucursal,
    v.cantidad as cantidad_vendida, v.fecha as fecha_venta, v.estado,
    case
      when v.id_detalle is null then 'SIN_LINEA_ORIGEN'
      when v.estado != 'COMPLETADA' then 'VENTA_NO_COMPLETADA'
      when d.fecha < v.fecha then 'FECHA_ANTERIOR_A_VENTA'
      when d.cantidad <= 0 then 'CANTIDAD_NO_POSITIVA'
      when d.cantidad_total_devuelta > v.cantidad then 'CANTIDAD_SUPERIOR_A_VENTA'
      else 'VALIDA'
    end as resultado_validacion,
    round(d.cantidad * v.subtotal / nullif(v.cantidad, 0), 2) as importe_estimado
from devoluciones d
left join {{ ref('int_ventas') }} v using (id_venta, id_producto)
