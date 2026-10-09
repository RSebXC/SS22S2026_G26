select
    nullif(trim("id_venta"), '')::bigint as id_venta,
    nullif(trim("fecha"), '')::date as fecha,
    nullif(trim("id_cliente"), '')::int as id_cliente,
    nullif(trim("id_sucursal"), '')::int as id_sucursal,
    nullif(trim("canal"), '')::text as canal,
    nullif(trim("metodo_pago"), '')::text as metodo_pago,
    nullif(trim("estado"), '')::text as estado,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'venta') }}
