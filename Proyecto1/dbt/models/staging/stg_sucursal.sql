select
    nullif(trim("id_sucursal"), '')::int as id_sucursal,
    nullif(trim("nombre"), '')::text as nombre,
    nullif(trim("ciudad"), '')::text as ciudad,
    nullif(trim("departamento"), '')::text as departamento,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'sucursal') }}
