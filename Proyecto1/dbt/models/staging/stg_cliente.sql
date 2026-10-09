select
    nullif(trim("id_cliente"), '')::int as id_cliente,
    nullif(trim("nit"), '')::text as nit,
    nullif(trim("nombre"), '')::text as nombre,
    nullif(trim("tipo_cliente"), '')::text as tipo_cliente,
    nullif(trim("municipio"), '')::text as municipio,
    nullif(trim("departamento"), '')::text as departamento,
    nullif(trim("fecha_alta"), '')::date as fecha_alta,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'cliente') }}
