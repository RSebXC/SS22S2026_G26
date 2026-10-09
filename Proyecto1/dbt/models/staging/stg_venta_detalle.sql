select
    nullif(trim("id_detalle"), '')::bigint as id_detalle,
    nullif(trim("id_venta"), '')::bigint as id_venta,
    nullif(trim("id_producto"), '')::int as id_producto,
    nullif(trim("cantidad"), '')::int as cantidad,
    nullif(trim("precio_unitario"), '')::numeric(12,2) as precio_unitario,
    nullif(trim("descuento"), '')::numeric(5,4) as descuento,
    nullif(trim("subtotal"), '')::numeric(14,2) as subtotal,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'venta_detalle') }}
