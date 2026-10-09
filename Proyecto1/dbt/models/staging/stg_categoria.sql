select
    nullif(trim("id_categoria"), '')::int as id_categoria,
    nullif(trim("nombre"), '')::text as nombre,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'categoria') }}
