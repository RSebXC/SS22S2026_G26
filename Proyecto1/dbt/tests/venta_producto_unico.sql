select id_venta,id_producto from {{ ref('stg_venta_detalle') }}
group by id_venta,id_producto having count(*) != 1
