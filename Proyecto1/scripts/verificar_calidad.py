"""Comprueba los diez casos inválidos dentro de transacciones revertidas.

Se ejecutan las mismas consultas singulares compiladas por dbt contra vistas
staging/intermediate. Ninguna modificación de raw queda confirmada.
"""
import json
from datetime import datetime, timezone
from pathlib import Path

from psycopg2 import sql
from src.files import read_csv
from src.pipeline import connect, save_json

ROOT = Path(__file__).resolve().parents[1]
CASES = {
    ('cliente','id_cliente'): ('cliente', 'cliente_id_no_nulo'),
    ('producto','precio_lista'): ('producto', 'producto_rangos'),
    ('venta','id_cliente'): ('venta', 'staging_integridad'),
    ('venta_detalle','cantidad'): ('venta_detalle','ventas_subtotal'),
    ('venta_detalle','descuento'): ('venta_detalle','ventas_subtotal'),
    ('inventario','stock_disponible'): ('inventario_bodega','inventario_rangos'),
    ('inventario','fecha_vencimiento'): ('inventario_bodega','inventario_rangos'),
    ('proveedores_precios','costo_proveedor'): ('proveedores_precios','proveedor_rangos'),
    ('metas_ventas','meta_ventas'): ('metas_ventas','metas_rangos'),
    ('devoluciones','cantidad'): ('devoluciones','devoluciones_invalidas'),
}


def main():
    cases = read_csv(ROOT/'data/input/casos_calidad_opcionales.csv',
                     ['entidad','campo','valor_prueba','tipo_incidencia'])
    results = []
    connection = connect('dw')
    try:
        for entity,field,value,description in cases:
            table, test = CASES[(entity,field)]
            query = (ROOT/f'dbt/target/compiled/sgfood/tests/{test}.sql').read_text(encoding='utf-8')
            with connection.cursor() as cursor:
                cursor.execute(query)
                baseline = len(cursor.fetchall())
                cursor.execute(sql.SQL('UPDATE raw.{} SET {}=%s WHERE _source_row=(SELECT min(_source_row) FROM raw.{})').format(
                    sql.Identifier(table),sql.Identifier(field),sql.Identifier(table)), (value or None,))
                cursor.execute(query)
                failures = len(cursor.fetchall())
            connection.rollback()
            results.append({'entity':entity,'field':field,'description':description,'test':test,
                            'baseline_failures':baseline,'injected_failures':failures,'detected':failures>baseline,
                            'persisted':False})
    finally:
        connection.rollback()
        connection.close()
    save_json('casos_calidad.json', {'generated_at_utc':datetime.now(timezone.utc),'cases':results,
                                   'all_detected':all(r['detected'] for r in results)})
    if not all(r['detected'] for r in results):
        raise RuntimeError('Alguna regla no detectó su caso inválido; consultar evidence/casos_calidad.json')
    print(f'{len(results)}/{len(results)} casos inválidos detectados; transacciones revertidas')


if __name__ == '__main__':
    main()
