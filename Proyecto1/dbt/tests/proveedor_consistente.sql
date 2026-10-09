select id_proveedor from {{ ref('stg_proveedores_precios') }}
group by id_proveedor having count(distinct proveedor) != 1
