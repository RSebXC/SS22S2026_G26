select id_cliente as cliente_key, id_cliente, nit, nombre, tipo_cliente, municipio, departamento, fecha_alta
from {{ ref('stg_cliente') }}
