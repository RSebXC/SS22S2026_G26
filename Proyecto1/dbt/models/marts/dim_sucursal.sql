select id_sucursal as sucursal_key, id_sucursal, nombre, ciudad, departamento
from {{ ref('stg_sucursal') }}
