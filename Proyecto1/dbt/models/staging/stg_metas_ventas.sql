select
    nullif(trim("periodo"), '')::text as periodo,
    nullif(trim("id_sucursal"), '')::int as id_sucursal,
    nullif(trim("meta_ventas"), '')::numeric(14,2) as meta_ventas,
    nullif(trim("meta_unidades"), '')::int as meta_unidades,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'metas_ventas') }}
