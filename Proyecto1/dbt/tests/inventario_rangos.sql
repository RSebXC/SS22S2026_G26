select * from {{ ref('stg_inventario_bodega') }}
where stock_disponible is null or stock_disponible < 0 or stock_minimo is null or stock_minimo < 0
or stock_maximo is null or stock_maximo < stock_minimo
or fecha_corte is null or fecha_vencimiento is null or fecha_vencimiento < fecha_corte or lote is null
