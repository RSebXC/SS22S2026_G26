select 'lineas_perdidas' as error
where (select count(*) from {{ ref('stg_venta_detalle') }}) != (select count(*) from {{ ref('fact_ventas') }})
