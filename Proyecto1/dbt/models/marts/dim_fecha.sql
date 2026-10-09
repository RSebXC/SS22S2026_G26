with fechas as (
    select fecha as fecha from {{ ref('stg_venta') }}
    union all select fecha_corte from {{ ref('stg_inventario_bodega') }}
    union all select fecha_vencimiento from {{ ref('stg_inventario_bodega') }}
    union all select fecha from {{ ref('stg_devoluciones') }}
    union all select (periodo || '-01')::date from {{ ref('stg_metas_ventas') }}
    union all select fecha_vigencia from {{ ref('stg_proveedores_precios') }}
    union all select fecha_inicio from {{ ref('stg_promociones') }}
    union all select fecha_fin from {{ ref('stg_promociones') }}
), calendario as (
    select generate_series(min(fecha)::timestamp, max(fecha)::timestamp, interval '1 day')::date as fecha
    from fechas
)
select to_char(fecha, 'YYYYMMDD')::int as fecha_key, fecha,
    extract(year from fecha)::int as anio, extract(quarter from fecha)::int as trimestre,
    extract(month from fecha)::int as mes, to_char(fecha, 'YYYY-MM') as periodo,
    extract(day from fecha)::int as dia,
    extract(isodow from fecha)::int as dia_semana,
    (array['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'])[extract(month from fecha)::int] as nombre_mes
from calendario
