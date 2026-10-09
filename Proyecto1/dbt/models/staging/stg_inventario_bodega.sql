select
    nullif(trim("fecha_corte"), '')::date as fecha_corte,
    nullif(trim("id_sucursal"), '')::int as id_sucursal,
    nullif(trim("id_producto"), '')::int as id_producto,
    nullif(trim("stock_disponible"), '')::int as stock_disponible,
    nullif(trim("stock_minimo"), '')::int as stock_minimo,
    nullif(trim("stock_maximo"), '')::int as stock_maximo,
    nullif(trim("lote"), '')::text as lote,
    nullif(trim("fecha_vencimiento"), '')::date as fecha_vencimiento,
    _loaded_at, _source, _batch_id, _source_row
from {{ source('sgfood_raw', 'inventario_bodega') }}
