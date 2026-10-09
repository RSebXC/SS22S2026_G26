select fecha_corte,id_sucursal,id_producto,lote from {{ ref('stg_inventario_bodega') }}
group by fecha_corte,id_sucursal,id_producto,lote having count(*) != 1
