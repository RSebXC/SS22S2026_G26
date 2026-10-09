select id_devolucion as devolucion_key, id_devolucion, id_venta, id_detalle,
    to_char(fecha,'YYYYMMDD')::int as fecha_key,
    id_producto as producto_key, id_cliente as cliente_key, id_sucursal as sucursal_key,
    cantidad, motivo, resultado_validacion,
    resultado_validacion = 'VALIDA' as es_valida,
    case when resultado_validacion = 'VALIDA' then importe_estimado else 0 end as importe_devolucion_estimado,
    case when resultado_validacion = 'VALIDA' then cantidad else 0 end as unidades_devueltas_validas
from {{ ref('int_devoluciones') }}
