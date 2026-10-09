select
    nullif(trim("id_promocion"), '')::int as id_promocion,
    nullif(trim("nombre"), '')::text as nombre,
    nullif(trim("fecha_inicio"), '')::date as fecha_inicio,
    nullif(trim("fecha_fin"), '')::date as fecha_fin,
    nullif(trim("id_categoria"), '')::int as id_categoria,
    nullif(trim("porcentaje_descuento"), '')::numeric(5,4) as porcentaje_descuento,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'promociones') }}
