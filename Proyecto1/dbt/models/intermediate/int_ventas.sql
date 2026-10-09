select
    d.id_detalle, d.id_venta, d.id_producto, v.id_cliente, v.id_sucursal,
    v.fecha, v.canal, v.metodo_pago, v.estado,
    d.cantidad, d.precio_unitario, d.descuento, d.subtotal,
    round(d.cantidad * d.precio_unitario, 2) as importe_bruto,
    round(d.cantidad * d.precio_unitario * d.descuento, 2) as importe_descuento,
    round(d.cantidad * p.costo_base, 2) as costo_referencia,
    p.id_categoria,
    case when v.estado = 'COMPLETADA' then d.subtotal else 0 end as importe_neto_vendido,
    case when v.estado = 'COMPLETADA' then d.cantidad else 0 end as unidades_vendidas
from {{ ref('stg_venta_detalle') }} d
join {{ ref('stg_venta') }} v using (id_venta)
join {{ ref('stg_producto') }} p using (id_producto)
