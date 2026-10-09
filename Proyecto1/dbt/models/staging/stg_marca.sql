select
    nullif(trim("id_marca"), '')::int as id_marca,
    nullif(trim("nombre"), '')::text as nombre,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'marca') }}
