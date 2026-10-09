select md5(concat_ws('|',periodo,id_sucursal::text)) as meta_key,
    to_char((periodo||'-01')::date,'YYYYMMDD')::int as fecha_key,
    id_sucursal as sucursal_key, periodo, meta_ventas, meta_unidades
from {{ ref('stg_metas_ventas') }}
