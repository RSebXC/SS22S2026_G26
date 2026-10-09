"""Genera evidencia y resultados a partir del DW efectivamente ejecutado."""
import json
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from src.pipeline import connect, save_json

ROOT = Path(__file__).resolve().parents[1]
QUERIES = {
    'resumen': '''select sum(importe_neto_vendido) as ventas_completadas,
      sum(unidades_vendidas) as unidades_vendidas,
      count(distinct id_venta) filter (where estado='COMPLETADA') as tickets,
      sum(margen_estimado) as margen_estimado,
      sum(importe_neto_vendido)/nullif(count(distinct id_venta) filter (where estado='COMPLETADA'),0) as ticket_promedio
      from marts.fact_ventas''',
    'mensual': '''select periodo, sum(ventas_completadas) as ventas,
      sum(devoluciones_estimadas) as devoluciones_estimadas, sum(meta_ventas) as meta,
      sum(ventas_completadas)/nullif(sum(meta_ventas),0) as cumplimiento
      from marts.rpt_ventas_mensuales group by periodo order by periodo''',
    'categorias': '''select p.categoria,sum(v.importe_neto_vendido) as ventas
      from marts.fact_ventas v join marts.dim_producto p using(producto_key)
      group by p.categoria order by ventas desc''',
    'sucursales': '''select sucursal,sum(ventas_completadas) as ventas,
      sum(meta_ventas) as meta,sum(ventas_completadas)/nullif(sum(meta_ventas),0) as cumplimiento
      from marts.rpt_ventas_mensuales group by sucursal order by ventas desc''',
    'inventario': '''select max(fecha_corte) as fecha_corte,count(*) as posiciones,
      sum(stock_disponible) as existencias,count(*) filter(where sin_stock) as sin_stock,
      count(*) filter(where bajo_minimo) as bajo_minimo,
      count(*) filter(where sobre_maximo) as sobre_maximo,
      count(*) filter(where vence_en_30_dias) as vence_en_30_dias,
      sum(valor_inventario_referencia) as valor_referencia from marts.rpt_inventario_actual''',
    'devoluciones': 'select * from marts.rpt_calidad_devoluciones order by resultado_validacion',
    'estados': 'select estado,count(*) as ventas from staging.stg_venta group by estado order by estado',
    'claves': '''select c.contype as tipo,count(*) as cantidad
      from pg_constraint c join pg_namespace n on n.oid=c.connamespace
      where n.nspname='marts' group by c.contype order by c.contype''',
}


def main():
    result = {'generated_at_utc': datetime.now(timezone.utc)}
    with connect('dw') as connection, connection.cursor() as cursor:
        for name, query in QUERIES.items():
            cursor.execute(query)
            result[name] = [dict(zip([c.name for c in cursor.description],row)) for row in cursor.fetchall()]
    path = ROOT / 'evidence/dbt_resultados.json'
    if path.exists():
        artifact = json.loads(path.read_text(encoding='utf-8'))
        result['dbt'] = dict(Counter(r['status'] for r in artifact['results']))
        result['dbt_models'] = sum(r['unique_id'].startswith('model.') for r in artifact['results'])
        result['dbt_tests'] = sum(r['unique_id'].startswith('test.') for r in artifact['results'])
        result['dbt_elapsed_seconds'] = artifact['elapsed_time']
    save_json('resultados_analiticos.json', result)
    def table(rows):
        if not rows:
            return 'Sin filas.'
        columns = list(rows[0])
        return '\n'.join(['| ' + ' | '.join(columns) + ' |', '| ' + ' | '.join(['---']*len(columns)) + ' |'] + [
            '| ' + ' | '.join(f'{row[c]:,.2f}' if hasattr(row[c],'as_tuple') else str(row[c]) for c in columns) + ' |'
            for row in rows])
    text = '# Resultados verificados\n\nGenerados mediante consultas al PostgreSQL del proyecto; todos los datos de la fuente son ficticios.\n\n'
    text += '''## Gráficas

![Ventas por mes](graficas/ventas_mensuales.svg)

![Ventas por categoría](graficas/ventas_categorias.svg)

![Ventas por sucursal](graficas/ventas_sucursales.svg)

Gráficas SVG regenerables con `python scripts/generar_graficas.py`. Los importes se presentan en unidades monetarias del dataset, que no incluye un campo de moneda.

'''
    total = result['resumen'][0]
    inventory = result['inventario'][0]
    total_target = sum(r['meta'] for r in result['mensual'])
    top_month = max(result['mensual'],key=lambda r:r['ventas'])
    text += ('## Hallazgos\n\n'
        f"- Se registraron {total['tickets']:,} ventas completadas, {total['unidades_vendidas']:,} unidades y {total['ventas_completadas']:,.2f} en ventas.\n"
        f"- El mes de mayor venta fue {top_month['periodo']} con {top_month['ventas']:,.2f}.\n"
        f"- {result['categorias'][0]['categoria']} lidera categorías y {result['sucursales'][0]['sucursal']} lidera sucursales.\n"
        f"- El cumplimiento agregado de las metas es {total['ventas_completadas']/total_target:.2%}. Las metas sintéticas están muy por encima de las ventas observadas; no se infieren causas empresariales reales.\n"
        f"- Al corte {inventory['fecha_corte']} hay {inventory['sin_stock']} posiciones sin stock y {inventory['bajo_minimo']} bajo mínimo, de {inventory['posiciones']} posiciones. Revisar reposición y lotes próximos a vencer.\n\n")
    for name in QUERIES:
        text += f'## {name.replace("_", " ").capitalize()}\n\n{table(result[name])}\n\n'
    if 'dbt' in result:
        text += '## Ejecución dbt\n\n' + json.dumps(result['dbt'],ensure_ascii=False) + '\n\n'
    text += '''## Interpretación y límites

Ventas completadas corresponden al subtotal después del descuento original; las pendientes y anuladas se conservan pero no contribuyen a ventas. El margen es una estimación que usa costo_base actual, sin gastos, impuestos ni historial de costos. No es utilidad contable.

Las metas se comparan con ventas completadas. Su cumplimiento debe calcularse como suma de ventas / suma de metas; no promediar porcentajes de sucursales. Las devoluciones se reconocen en su propia fecha y se valoran proporcionalmente al neto de la venta, porque no se proporciona un importe de reembolso.

Cantidades y existencias suman las unidades comerciales originales, que pueden ser cajas, botellas, paquetes u otras presentaciones. No representan un volumen físico homogéneo; para comparar volúmenes, agrupar por producto o unidad_medida y disponer de factores de conversión.

El inventario corresponde al último corte disponible. Las existencias no deben sumarse entre cortes: el mismo producto puede aparecer en varios meses. Los umbrales y vencimientos se calculan respecto a la fecha de corte.

La coincidencia de una venta con una promoción representa elegibilidad potencial. El dataset no incluye un identificador de promoción aplicada; no se atribuye causalidad ni se descuenta nuevamente.
'''
    (ROOT / 'docs/resultados.md').write_text(text,encoding='utf-8')
    print('Resultados reales guardados en docs/resultados.md y evidence/')


if __name__ == '__main__':
    main()
