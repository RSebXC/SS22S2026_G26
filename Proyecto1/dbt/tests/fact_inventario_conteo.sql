select 'snapshots_perdidos' as error
where (select count(*) from {{ ref('stg_inventario_bodega') }}) != (select count(*) from {{ ref('fact_inventario') }})
