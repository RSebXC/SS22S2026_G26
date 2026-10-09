select
    nullif(trim("id_producto"), '')::int as id_producto,
    nullif(trim("sku"), '')::text as sku,
    nullif(trim("nombre"), '')::text as nombre,
    nullif(trim("id_categoria"), '')::int as id_categoria,
    nullif(trim("id_marca"), '')::int as id_marca,
    nullif(trim("unidad_medida"), '')::text as unidad_medida,
    nullif(trim("costo_base"), '')::numeric(12,2) as costo_base,
    nullif(trim("precio_lista"), '')::numeric(12,2) as precio_lista,
    nullif(trim("activo"), '')::boolean as activo,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'producto') }}
