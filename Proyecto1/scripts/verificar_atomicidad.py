"""Inyecta un fallo de lectura al final de la carga y comprueba el rollback."""
from datetime import datetime, timezone
from unittest.mock import patch

from psycopg2 import sql
from src import pipeline
from src.schema import TABLES


def signature():
    with pipeline.connect('dw') as connection, connection.cursor() as cursor:
        result = {}
        for name in TABLES:
            cursor.execute(sql.SQL("SELECT count(*),min(_batch_id::text),max(_batch_id::text) FROM raw.{}").format(sql.Identifier(name)))
            result[name] = cursor.fetchone()
        cursor.execute('SELECT count(*) FROM audit.load_runs')
        result['audit_count'] = cursor.fetchone()[0]
    return result


before = signature()
original_reader = pipeline.read_csv


def fail_last(path,columns):
    if path.name == 'devoluciones.csv':
        raise ValueError('Fallo simulado de lectura en la última fuente')
    return original_reader(path,columns)


with patch.object(pipeline,'read_csv',fail_last):
    try:
        pipeline.load_raw()
    except ValueError as error:
        if str(error) != 'Fallo simulado de lectura en la última fuente':
            raise
    else:
        raise RuntimeError('La carga no falló como se esperaba')
after = signature()
pipeline.save_json('atomicidad.json', {
    'generated_at_utc':datetime.now(timezone.utc),
    'injected_failure':'lectura de la última fuente CSV, después de reemplazar otras 11 tablas',
    'raw_and_audit_unchanged':before==after,
    'before':before, 'after':after,
})
if before != after:
    raise RuntimeError('La carga dejó cambios parciales')
print('Rollback confirmado: 12 tablas raw y auditoría conservadas')
