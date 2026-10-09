select * from {{ ref('stg_metas_ventas') }}
where periodo is null or periodo !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
or meta_ventas is null or meta_ventas <= 0 or meta_unidades is null or meta_unidades <= 0
