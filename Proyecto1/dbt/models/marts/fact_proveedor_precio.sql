select md5(concat_ws('|',id_proveedor::text,id_producto::text,fecha_vigencia::text)) as precio_key,
    id_proveedor as proveedor_key, id_producto as producto_key,
    to_char(fecha_vigencia,'YYYYMMDD')::int as fecha_key,
    costo_proveedor, plazo_dias, fecha_vigencia
from {{ ref('stg_proveedores_precios') }}
