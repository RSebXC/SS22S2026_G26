select
    nullif(trim("id_devolucion"), '')::bigint as id_devolucion,
    nullif(trim("fecha"), '')::date as fecha,
    nullif(trim("id_venta"), '')::bigint as id_venta,
    nullif(trim("id_producto"), '')::int as id_producto,
    nullif(trim("cantidad"), '')::int as cantidad,
    nullif(trim("motivo"), '')::text as motivo,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'devoluciones') }}
