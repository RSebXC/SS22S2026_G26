select md5(concat_ws('|',fecha_corte::text,id_sucursal::text,id_producto::text,lote)) as inventario_key,
    to_char(fecha_corte,'YYYYMMDD')::int as fecha_key,
    to_char(fecha_vencimiento,'YYYYMMDD')::int as vencimiento_fecha_key,
    id_sucursal as sucursal_key, i.id_producto as producto_key,
    i.lote, i.stock_disponible, i.stock_minimo, i.stock_maximo, i.fecha_vencimiento,
    round(i.stock_disponible * p.costo_base,2) as valor_inventario_referencia,
    i.stock_disponible = 0 as sin_stock,
    i.stock_disponible < i.stock_minimo as bajo_minimo,
    i.stock_disponible > i.stock_maximo as sobre_maximo,
    i.fecha_vencimiento - i.fecha_corte as dias_para_vencer,
    i.fecha_vencimiento < i.fecha_corte as vencido,
    i.fecha_vencimiento between i.fecha_corte and i.fecha_corte + 30 as vence_en_30_dias
from {{ ref('stg_inventario_bodega') }} i
join {{ ref('stg_producto') }} p using (id_producto)
