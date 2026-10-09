select
    nullif(trim("id_proveedor"), '')::int as id_proveedor,
    nullif(trim("proveedor"), '')::text as proveedor,
    nullif(trim("id_producto"), '')::int as id_producto,
    nullif(trim("costo_proveedor"), '')::numeric(12,2) as costo_proveedor,
    nullif(trim("plazo_dias"), '')::int as plazo_dias,
    nullif(trim("fecha_vigencia"), '')::date as fecha_vigencia,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'proveedores_precios') }}
