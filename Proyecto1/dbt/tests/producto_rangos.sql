select * from {{ ref('stg_producto') }}
where id_producto is null or sku is null or nombre is null
or costo_base is null or costo_base < 0 or precio_lista is null or precio_lista < 0
