select id_detalle as venta_key, id_detalle, id_venta,
    to_char(fecha,'YYYYMMDD')::int as fecha_key,
    id_producto as producto_key, id_cliente as cliente_key, id_sucursal as sucursal_key,
    md5(canal) as canal_key, md5(metodo_pago) as pago_key, estado,
    cantidad, precio_unitario, descuento, importe_bruto, importe_descuento,
    subtotal as importe_neto_linea, importe_neto_vendido, unidades_vendidas,
    costo_referencia,
    case when estado='COMPLETADA' then costo_referencia else 0 end as costo_estimado_vendido,
    case when estado='COMPLETADA' then subtotal-costo_referencia else 0 end as margen_estimado
from {{ ref('int_ventas') }}
