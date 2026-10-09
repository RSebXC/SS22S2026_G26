select * from {{ ref('stg_proveedores_precios') }}
where costo_proveedor is null or costo_proveedor < 0 or plazo_dias is null or plazo_dias <= 0 or fecha_vigencia is null
