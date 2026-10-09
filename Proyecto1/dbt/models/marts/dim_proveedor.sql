select id_proveedor as proveedor_key, id_proveedor, min(proveedor) as proveedor
from {{ ref('stg_proveedores_precios') }} group by id_proveedor
