"""Generador inicial de archivos estáticos. No ejecutar después de editarlos.

Los archivos SQL/YAML generados son el código del proyecto y pueden modificarse
directamente. Este script se conserva como registro de su creación inicial.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from src.schema import TABLES


def write(name, text):
    path = ROOT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        raise FileExistsError(f'No se sobrescribe {name}; editar el archivo directamente')
    path.write_text(text.strip() + '\n', encoding='utf-8')


raw = [
    '-- Raw preserva valores originales; los tipos y reglas se aplican en dbt.',
    'CREATE SCHEMA IF NOT EXISTS raw;', 'CREATE SCHEMA IF NOT EXISTS audit;',
    '''CREATE TABLE IF NOT EXISTS audit.load_runs (
      batch_id UUID PRIMARY KEY, started_at TIMESTAMPTZ NOT NULL,
      completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      counts JSONB NOT NULL, file_hashes JSONB NOT NULL
    );''',
]
for table, fields in TABLES.items():
    columns = ',\n    '.join(f'"{name}" TEXT' for name, _ in fields)
    raw.append(f'''CREATE TABLE IF NOT EXISTS raw.{table} (
    {columns},
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );''')
    casts = ',\n    '.join(f'nullif(trim("{name}"), \'\')::{dtype} as {name}' for name, dtype in fields)
    write(f'dbt/models/staging/stg_{table}.sql', f'''select
    {casts},
    _loaded_at, _source, _batch_id, _source_row
from {{{{ source('sgfood_raw', '{table}') }}}}''')
write('sql/01_raw.sql', '\n\n'.join(raw))
sources = {'version': 2, 'sources': [{'name': 'sgfood_raw', 'schema': 'raw', 'description': 'Snapshot de la BD transaccional y de los CSV originales; cargado atómicamente por Python.', 'tables': [
    {'name': name, 'description': f'Fuente original de {name}; conservar su grano y metadatos.', 'columns': [
        {'name': '_batch_id', 'data_tests': ['not_null']}, {'name': '_source_row', 'data_tests': ['not_null', 'unique']}
    ]} for name in TABLES
]}]}
# JSON es YAML válido y evita una dependencia de generación.
write('dbt/models/sources.yml', json.dumps(sources, indent=2, ensure_ascii=False))
write('dbt/dbt_project.yml', '''name: sgfood
version: '1.0.0'
config-version: 2
profile: sgfood
model-paths: [models]
test-paths: [tests]
macro-paths: [macros]
clean-targets: [target, dbt_packages]
models:
  sgfood:
    staging:
      +schema: staging
      +materialized: view
    intermediate:
      +schema: intermediate
      +materialized: view
    marts:
      +schema: marts
      +materialized: table
''')
write('dbt/profiles.yml', '''sgfood:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('DBT_HOST', 'postgres') }}"
      port: "{{ env_var('DBT_PORT', '5432') | int }}"
      user: "{{ env_var('DBT_USER', 'sgfood') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      dbname: "{{ env_var('DBT_DATABASE', 'sgfood_dw') }}"
      schema: marts
      threads: 4
      connect_timeout: 15
''')
write('dbt/macros/generate_schema_name.sql', '''{% macro generate_schema_name(custom_schema_name, node) -%}
  {{ custom_schema_name | trim if custom_schema_name else target.schema }}
{%- endmacro %}''')
write('dbt/models/intermediate/int_ventas.sql', '''select
    d.id_detalle, d.id_venta, d.id_producto, v.id_cliente, v.id_sucursal,
    v.fecha, v.canal, v.metodo_pago, v.estado,
    d.cantidad, d.precio_unitario, d.descuento, d.subtotal,
    round(d.cantidad * d.precio_unitario, 2) as importe_bruto,
    round(d.cantidad * d.precio_unitario * d.descuento, 2) as importe_descuento,
    round(d.cantidad * p.costo_base, 2) as costo_referencia,
    p.id_categoria,
    case when v.estado = 'COMPLETADA' then d.subtotal else 0 end as importe_neto_vendido,
    case when v.estado = 'COMPLETADA' then d.cantidad else 0 end as unidades_vendidas
from {{ ref('stg_venta_detalle') }} d
join {{ ref('stg_venta') }} v using (id_venta)
join {{ ref('stg_producto') }} p using (id_producto)''')
write('dbt/models/intermediate/int_devoluciones.sql', '''with devoluciones as (
    select *, sum(cantidad) over (partition by id_venta, id_producto) as cantidad_total_devuelta
    from {{ ref('stg_devoluciones') }}
)
select d.*, v.id_detalle, v.id_cliente, v.id_sucursal,
    v.cantidad as cantidad_vendida, v.fecha as fecha_venta, v.estado,
    case
      when v.id_detalle is null then 'SIN_LINEA_ORIGEN'
      when v.estado != 'COMPLETADA' then 'VENTA_NO_COMPLETADA'
      when d.fecha < v.fecha then 'FECHA_ANTERIOR_A_VENTA'
      when d.cantidad <= 0 then 'CANTIDAD_NO_POSITIVA'
      when d.cantidad_total_devuelta > v.cantidad then 'CANTIDAD_SUPERIOR_A_VENTA'
      else 'VALIDA'
    end as resultado_validacion,
    round(d.cantidad * v.subtotal / nullif(v.cantidad, 0), 2) as importe_estimado
from devoluciones d
left join {{ ref('int_ventas') }} v using (id_venta, id_producto)''')

models = {
'dim_fecha': '''with fechas as (
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
from calendario''',
'dim_producto': '''select p.id_producto as producto_key, p.*, c.nombre as categoria, m.nombre as marca
from {{ ref('stg_producto') }} p
join {{ ref('stg_categoria') }} c using (id_categoria)
join {{ ref('stg_marca') }} m using (id_marca)''',
'dim_cliente': '''select id_cliente as cliente_key, id_cliente, nit, nombre, tipo_cliente, municipio, departamento, fecha_alta
from {{ ref('stg_cliente') }}''',
'dim_sucursal': '''select id_sucursal as sucursal_key, id_sucursal, nombre, ciudad, departamento
from {{ ref('stg_sucursal') }}''',
'dim_canal': '''select distinct md5(canal) as canal_key, canal from {{ ref('stg_venta') }}''',
'dim_pago': '''select distinct md5(metodo_pago) as pago_key, metodo_pago from {{ ref('stg_venta') }}''',
'dim_proveedor': '''select id_proveedor as proveedor_key, id_proveedor, min(proveedor) as proveedor
from {{ ref('stg_proveedores_precios') }} group by id_proveedor''',
'dim_promocion': '''select id_promocion as promocion_key, p.id_promocion, p.nombre, p.fecha_inicio, p.fecha_fin,
    p.id_categoria, c.nombre as categoria, p.porcentaje_descuento
from {{ ref('stg_promociones') }} p join {{ ref('stg_categoria') }} c using (id_categoria)''',
'fact_ventas': '''select id_detalle as venta_key, id_detalle, id_venta,
    to_char(fecha,'YYYYMMDD')::int as fecha_key,
    id_producto as producto_key, id_cliente as cliente_key, id_sucursal as sucursal_key,
    md5(canal) as canal_key, md5(metodo_pago) as pago_key, estado,
    cantidad, precio_unitario, descuento, importe_bruto, importe_descuento,
    subtotal as importe_neto_linea, importe_neto_vendido, unidades_vendidas,
    costo_referencia,
    case when estado='COMPLETADA' then costo_referencia else 0 end as costo_estimado_vendido,
    case when estado='COMPLETADA' then subtotal-costo_referencia else 0 end as margen_estimado
from {{ ref('int_ventas') }}''',
'fact_inventario': '''select md5(concat_ws('|',fecha_corte::text,id_sucursal::text,id_producto::text,lote)) as inventario_key,
    to_char(fecha_corte,'YYYYMMDD')::int as fecha_key,
    to_char(fecha_vencimiento,'YYYYMMDD')::int as vencimiento_fecha_key,
    id_sucursal as sucursal_key, i.id_producto as producto_key,
    i.lote, i.stock_disponible, i.stock_minimo, i.stock_maximo, i.fecha_vencimiento,
    round(i.stock_disponible * p.costo_base,2) as valor_inventario_referencia,
    i.stock_disponible = 0 as sin_stock,
    i.stock_disponible < i.stock_minimo as bajo_minimo,
    i.stock_disponible > i.stock_maximo as sobre_maximo,
    i.fecha_vencimiento - i.fecha_corte as dias_para_vencer,
    i.fecha_vencimiento < i.fecha_corte as vencido,
    i.fecha_vencimiento between i.fecha_corte and i.fecha_corte + 30 as vence_en_30_dias
from {{ ref('stg_inventario_bodega') }} i
join {{ ref('stg_producto') }} p using (id_producto)''',
'fact_devoluciones': '''select id_devolucion as devolucion_key, id_devolucion, id_venta, id_detalle,
    to_char(fecha,'YYYYMMDD')::int as fecha_key,
    id_producto as producto_key, id_cliente as cliente_key, id_sucursal as sucursal_key,
    cantidad, motivo, resultado_validacion,
    resultado_validacion = 'VALIDA' as es_valida,
    case when resultado_validacion = 'VALIDA' then importe_estimado else 0 end as importe_devolucion_estimado,
    case when resultado_validacion = 'VALIDA' then cantidad else 0 end as unidades_devueltas_validas
from {{ ref('int_devoluciones') }}''',
'fact_metas': '''select md5(concat_ws('|',periodo,id_sucursal::text)) as meta_key,
    to_char((periodo||'-01')::date,'YYYYMMDD')::int as fecha_key,
    id_sucursal as sucursal_key, periodo, meta_ventas, meta_unidades
from {{ ref('stg_metas_ventas') }}''',
'fact_proveedor_precio': '''select md5(concat_ws('|',id_proveedor::text,id_producto::text,fecha_vigencia::text)) as precio_key,
    id_proveedor as proveedor_key, id_producto as producto_key,
    to_char(fecha_vigencia,'YYYYMMDD')::int as fecha_key,
    costo_proveedor, plazo_dias, fecha_vigencia
from {{ ref('stg_proveedores_precios') }}''',
'bridge_promocion_venta': '''select v.id_detalle as venta_key, p.id_promocion as promocion_key
from {{ ref('int_ventas') }} v
join {{ ref('stg_promociones') }} p on p.id_categoria = v.id_categoria
    and v.fecha between p.fecha_inicio and p.fecha_fin
where v.estado = 'COMPLETADA' ''',
'rpt_ventas_mensuales': '''with ventas as (
    select f.periodo, v.sucursal_key, count(distinct v.id_venta) filter (where v.estado='COMPLETADA') as tickets,
        sum(v.importe_neto_vendido) as ventas_completadas, sum(v.unidades_vendidas) as unidades_vendidas,
        sum(v.margen_estimado) as margen_estimado
    from {{ ref('fact_ventas') }} v join {{ ref('dim_fecha') }} f using (fecha_key)
    group by f.periodo, v.sucursal_key
), devoluciones as (
    select f.periodo, d.sucursal_key, sum(d.importe_devolucion_estimado) as devoluciones_estimadas
    from {{ ref('fact_devoluciones') }} d join {{ ref('dim_fecha') }} f using (fecha_key)
    group by f.periodo, d.sucursal_key
), metas as (select * from {{ ref('fact_metas') }}), claves as (
    select periodo,sucursal_key from ventas union select periodo,sucursal_key from metas
    union select periodo,sucursal_key from devoluciones
)
select k.periodo, k.sucursal_key, s.nombre as sucursal,
    coalesce(v.tickets,0) as tickets, coalesce(v.ventas_completadas,0) as ventas_completadas,
    coalesce(v.unidades_vendidas,0) as unidades_vendidas,
    coalesce(v.margen_estimado,0) as margen_estimado,
    coalesce(d.devoluciones_estimadas,0) as devoluciones_estimadas,
    coalesce(v.ventas_completadas,0)-coalesce(d.devoluciones_estimadas,0) as ventas_ajustadas_estimadas,
    m.meta_ventas, m.meta_unidades,
    coalesce(v.ventas_completadas,0)/nullif(m.meta_ventas,0) as cumplimiento_meta,
    coalesce(v.ventas_completadas,0)/nullif(v.tickets,0) as ticket_promedio
from claves k join {{ ref('dim_sucursal') }} s using (sucursal_key)
left join ventas v using (periodo,sucursal_key)
left join devoluciones d using (periodo,sucursal_key)
left join metas m using (periodo,sucursal_key)''',
'rpt_inventario_actual': '''select i.*, p.nombre as producto, p.categoria, p.marca,
    s.nombre as sucursal, f.fecha as fecha_corte
from {{ ref('fact_inventario') }} i
join {{ ref('dim_producto') }} p using (producto_key)
join {{ ref('dim_sucursal') }} s using (sucursal_key)
join {{ ref('dim_fecha') }} f using (fecha_key)
where i.fecha_key = (select max(fecha_key) from {{ ref('fact_inventario') }})''',
'rpt_calidad_devoluciones': '''select resultado_validacion, count(*) as registros, sum(cantidad) as unidades
from {{ ref('fact_devoluciones') }} group by resultado_validacion''',
}
for name, query in models.items():
    write(f'dbt/models/marts/{name}.sql', query)

keys = {
    'dim_fecha':'fecha_key', 'dim_producto':'producto_key', 'dim_cliente':'cliente_key',
    'dim_sucursal':'sucursal_key', 'dim_canal':'canal_key', 'dim_pago':'pago_key',
    'dim_proveedor':'proveedor_key', 'dim_promocion':'promocion_key',
    'fact_ventas':'venta_key', 'fact_inventario':'inventario_key', 'fact_devoluciones':'devolucion_key',
    'fact_metas':'meta_key', 'fact_proveedor_precio':'precio_key',
}
relationships = {
    'fact_ventas': {'fecha_key':'dim_fecha','producto_key':'dim_producto','cliente_key':'dim_cliente','sucursal_key':'dim_sucursal','canal_key':'dim_canal','pago_key':'dim_pago'},
    'fact_inventario': {'fecha_key':'dim_fecha','vencimiento_fecha_key':'dim_fecha','producto_key':'dim_producto','sucursal_key':'dim_sucursal'},
    'fact_devoluciones': {'fecha_key':'dim_fecha','producto_key':'dim_producto','cliente_key':'dim_cliente','sucursal_key':'dim_sucursal'},
    'fact_metas': {'fecha_key':'dim_fecha','sucursal_key':'dim_sucursal'},
    'fact_proveedor_precio': {'fecha_key':'dim_fecha','producto_key':'dim_producto','proveedor_key':'dim_proveedor'},
    'bridge_promocion_venta': {'venta_key':'fact_ventas','promocion_key':'dim_promocion'},
}
descriptions = {
    'fact_ventas':'Una línea original de venta. Importe neto vendido excluye estados distintos de COMPLETADA; margen usa costo_base de referencia y no representa utilidad contable.',
    'fact_inventario':'Un corte por fecha, sucursal, producto y lote. Existencias semiaditivas: nunca sumar entre cortes mensuales.',
    'fact_devoluciones':'Una devolución original con diagnóstico. Importe estimado proporcional al neto de la línea origen; solo las válidas afectan métricas.',
    'fact_metas':'Una meta mensual por sucursal; comparar con ventas completadas, antes de devoluciones.',
    'fact_proveedor_precio':'Una cotización por proveedor, producto y fecha de vigencia. No es evidencia de compras reales.',
    'bridge_promocion_venta':'Coincidencia por categoría y fechas; elegibilidad potencial, sin atribución causal ni ajuste adicional del descuento.',
    'rpt_ventas_mensuales':'Una fila por mes y sucursal. Devoluciones reconocidas en su fecha; hechos agregados por separado para evitar fanout.',
    'rpt_inventario_actual':'Último corte disponible del dataset, independiente de la fecha del equipo.',
}
properties = []
constraints = ['-- Aplicar después de cada dbt build: dbt recrea los marts.', '-- PK/FK físicas complementan las pruebas dbt.']
for name in models:
    columns = []
    if name in keys:
        key = keys[name]
        columns.append({'name': key, 'description':'Clave estable al grano documentado.', 'data_tests':['not_null','unique']})
        constraints.append(f'ALTER TABLE marts.{name} ADD PRIMARY KEY ({key});')
    for column, parent in relationships.get(name, {}).items():
        parent_key = keys[parent]
        tests = [{'relationships': {'arguments': {'to': "ref('" + parent + "')", 'field':parent_key}}}]
        if name != 'fact_devoluciones' or column not in ('cliente_key','sucursal_key'):
            tests.insert(0,'not_null')
        columns.append({'name':column, 'description':f'Relación con {parent}.{parent_key}', 'data_tests':tests})
    if name == 'fact_ventas':
        columns.append({'name':'estado','data_tests':[{'accepted_values':{'arguments':{'values':['COMPLETADA','PENDIENTE','ANULADA']}}}]})
    properties.append({'name': name, 'description':descriptions.get(name, f'Modelo {name} del Data Warehouse SG-Food.'), 'columns':columns})
constraints.append('ALTER TABLE marts.bridge_promocion_venta ADD PRIMARY KEY (venta_key, promocion_key);')
for name, relations in relationships.items():
    for column, parent in relations.items():
        constraints.append(f'ALTER TABLE marts.{name} ADD FOREIGN KEY ({column}) REFERENCES marts.{parent} ({keys[parent]});')
constraints += [
    'ALTER TABLE marts.fact_ventas ADD CHECK (cantidad > 0 AND precio_unitario >= 0 AND descuento BETWEEN 0 AND 1);',
    'ALTER TABLE marts.fact_inventario ADD CHECK (stock_disponible >= 0 AND stock_minimo >= 0 AND stock_maximo >= stock_minimo);',
    'ALTER TABLE marts.fact_metas ADD CHECK (meta_ventas > 0 AND meta_unidades > 0);',
    'ALTER TABLE marts.fact_proveedor_precio ADD CHECK (costo_proveedor >= 0 AND plazo_dias > 0);',
]
write('dbt/models/schema.yml', json.dumps({'version':2,'models':properties},indent=2,ensure_ascii=False))
write('sql/02_constraints.sql','\n'.join(constraints))

tests = {
'ventas_subtotal': '''select * from {{ ref('stg_venta_detalle') }}
where cantidad is null or cantidad <= 0 or precio_unitario is null or precio_unitario < 0
or descuento is null or descuento not between 0 and 1
or subtotal is null or abs(subtotal - round(cantidad * precio_unitario * (1 - descuento), 2)) > 0.01''',
'venta_producto_unico': '''select id_venta,id_producto from {{ ref('stg_venta_detalle') }}
group by id_venta,id_producto having count(*) != 1''',
'inventario_grano': '''select fecha_corte,id_sucursal,id_producto,lote from {{ ref('stg_inventario_bodega') }}
group by fecha_corte,id_sucursal,id_producto,lote having count(*) != 1''',
'inventario_rangos': '''select * from {{ ref('stg_inventario_bodega') }}
where stock_disponible is null or stock_disponible < 0 or stock_minimo is null or stock_minimo < 0
or stock_maximo is null or stock_maximo < stock_minimo
or fecha_corte is null or fecha_vencimiento is null or fecha_vencimiento < fecha_corte or lote is null''',
'metas_rangos': '''select * from {{ ref('stg_metas_ventas') }}
where periodo is null or periodo !~ '^[0-9]{4}-(0[1-9]|1[0-2])$'
or meta_ventas is null or meta_ventas <= 0 or meta_unidades is null or meta_unidades <= 0''',
'proveedor_consistente': '''select id_proveedor from {{ ref('stg_proveedores_precios') }}
group by id_proveedor having count(distinct proveedor) != 1''',
'proveedor_rangos': '''select * from {{ ref('stg_proveedores_precios') }}
where costo_proveedor is null or costo_proveedor < 0 or plazo_dias is null or plazo_dias <= 0 or fecha_vigencia is null''',
'promociones_rangos': '''select * from {{ ref('stg_promociones') }}
where fecha_inicio is null or fecha_fin is null or fecha_fin < fecha_inicio
or porcentaje_descuento is null or porcentaje_descuento not between 0 and 1''',
'devoluciones_id_unico': '''select id_devolucion from {{ ref('stg_devoluciones') }}
group by id_devolucion having id_devolucion is null or count(*) != 1''',
'devoluciones_invalidas': '''{{ config(severity='warn', store_failures=true) }}
select * from {{ ref('int_devoluciones') }} where resultado_validacion != 'VALIDA' ''',
'bridge_grano': '''select venta_key,promocion_key from {{ ref('bridge_promocion_venta') }}
group by venta_key,promocion_key having count(*) != 1''',
'fact_ventas_conteo': '''select 'lineas_perdidas' as error
where (select count(*) from {{ ref('stg_venta_detalle') }}) != (select count(*) from {{ ref('fact_ventas') }})''',
'fact_inventario_conteo': '''select 'snapshots_perdidos' as error
where (select count(*) from {{ ref('stg_inventario_bodega') }}) != (select count(*) from {{ ref('fact_inventario') }})''',
}
for name, query in tests.items():
    write(f'dbt/tests/{name}.sql', query)
print(f'Creados raw, {len(TABLES)} staging, {len(models)} marts y {len(tests)} pruebas singulares')
