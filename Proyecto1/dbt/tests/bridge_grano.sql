select venta_key,promocion_key from {{ ref('bridge_promocion_venta') }}
group by venta_key,promocion_key having count(*) != 1
