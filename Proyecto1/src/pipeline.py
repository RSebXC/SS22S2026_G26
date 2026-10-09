"""Carga transaccional de fuentes reales hacia PostgreSQL raw."""
import argparse
import csv
import hashlib
import json
import logging
import os
import shlex
import subprocess
import uuid
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values

from src.files import read_csv
from src.schema import CSV, OLTP, TABLES

ROOT = Path(__file__).resolve().parents[1]
LOG = logging.getLogger('sgfood')


def connect(kind):
    variable = 'SOURCE_DSN' if kind == 'source' else 'DW_DSN'
    if not os.environ.get(variable):
        raise RuntimeError(f'Falta configurar {variable}')
    return psycopg2.connect(os.environ[variable], connect_timeout=15)


def save_json(name, value):
    path = ROOT / 'evidence' / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False, default=str) + '\n', encoding='utf-8')


def init_source():
    """Bootstrap no destructivo: nunca vuelve a ejecutar DROP SCHEMA del insumo."""
    with connect('source') as connection, connection.cursor() as cursor:
        cursor.execute('SELECT current_database()')
        if cursor.fetchone()[0] != 'sgfood_source':
            raise RuntimeError('Bootstrap permitido únicamente en sgfood_source')
        cursor.execute("SELECT to_regclass('oltp_sgfood.venta')")
        if cursor.fetchone()[0]:
            LOG.info('Fuente ya inicializada; datos conservados')
            return
        payload = (ROOT / 'data/input/sgfood_oltp.sql').read_text(encoding='utf-8-sig')
        payload = payload.replace('DROP SCHEMA IF EXISTS oltp_sgfood CASCADE;', '')
        cursor.execute(payload)
    LOG.info('Fuente PostgreSQL inicializada')


def check_sources():
    for name in CSV:
        read_csv(ROOT / f'data/input/{name}.csv', [c for c, _ in TABLES[name]])
    for kind in ('source', 'dw'):
        with connect(kind) as connection, connection.cursor() as cursor:
            cursor.execute('SELECT 1')
            if kind == 'source':
                for name in OLTP:
                    cursor.execute(sql.SQL('SELECT {} FROM oltp_sgfood.{} LIMIT 1').format(
                        sql.SQL(',').join(sql.Identifier(c) for c, _ in TABLES[name]), sql.Identifier(name)))
                    if cursor.fetchone() is None:
                        raise ValueError(f'Fuente vacía: {name}')
    LOG.info('Conexiones y contratos de fuentes verificados')


def load_raw():
    """Snapshot completo y atómico: reintentos reemplazan raw sin duplicados."""
    batch = str(uuid.uuid4())
    started = datetime.now(timezone.utc)
    counts, fingerprints = {}, {}
    with connect('source') as source, connect('dw') as target:
        source.set_session(isolation_level='REPEATABLE READ', readonly=True)
        with source.cursor() as origin, target.cursor() as cursor:
            cursor.execute('SELECT pg_advisory_xact_lock(26001)')
            cursor.execute((ROOT / 'sql/01_raw.sql').read_text(encoding='utf-8'))
            for name, fields in TABLES.items():
                columns = [c for c, _ in fields]
                if name in OLTP:
                    origin.execute(sql.SQL('SELECT {} FROM oltp_sgfood.{} ORDER BY 1').format(
                        sql.SQL(',').join(map(sql.Identifier, columns)), sql.Identifier(name)))
                    rows = origin.fetchall()
                    source_name = f'sgfood_source.oltp_sgfood.{name}'
                else:
                    path = ROOT / f'data/input/{name}.csv'
                    rows = read_csv(path, columns)
                    fingerprints[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
                    source_name = path.name
                if not rows:
                    raise ValueError(f'No se permite reemplazar raw con una fuente vacía: {name}')
                cursor.execute(sql.SQL('TRUNCATE TABLE raw.{}').format(sql.Identifier(name)))
                query = sql.SQL('INSERT INTO raw.{} ({}) VALUES %s').format(
                    sql.Identifier(name), sql.SQL(',').join(map(sql.Identifier, columns + ['_source', '_batch_id', '_source_row'])))
                # Conservar el valor original; los casts y reglas de negocio pertenecen a dbt.
                values = [tuple(None if v is None else str(v) for v in row) + (source_name, batch, index)
                          for index, row in enumerate(rows, start=1)]
                execute_values(cursor, query.as_string(target), values, page_size=1000)
                counts[name] = len(rows)
                LOG.info('Cargadas %s: %s filas', name, len(rows))
            cursor.execute('INSERT INTO audit.load_runs(batch_id, started_at, counts, file_hashes) VALUES (%s,%s,%s::jsonb,%s::jsonb)',
                           (batch, started, json.dumps(counts), json.dumps(fingerprints)))
    result = {'batch_id': batch, 'started_at_utc': started, 'counts': counts, 'file_hashes': fingerprints}
    save_json('carga_raw.json', result)
    return result


def validate_raw():
    with connect('dw') as connection, connection.cursor() as cursor:
        cursor.execute('SELECT batch_id, counts FROM audit.load_runs ORDER BY completed_at DESC LIMIT 1')
        batch, expected = cursor.fetchone()
        for name, count in expected.items():
            cursor.execute(sql.SQL('SELECT count(*), count(*) FILTER (WHERE _batch_id != %s) FROM raw.{}').format(sql.Identifier(name)), (str(batch),))
            actual, mixed = cursor.fetchone()
            if actual != count or mixed:
                raise ValueError(f'Conteo o lote inconsistente en {name}: {actual} vs {count}')
    LOG.info('Conteos y lote raw conciliados')


def run_dbt(command):
    subprocess.run(['/opt/dbt/bin/dbt', *shlex.split(command), '--project-dir', str(ROOT / 'dbt'), '--profiles-dir', str(ROOT / 'dbt')], check=True)
    if command == 'build':
        save_dbt_results()


def save_dbt_results():
    # docs generate puede reemplazar run_results.json con resultados de compile.
    # Capturar el build antes de generar documentación preserva la evidencia de tests.
    artifact = json.loads((ROOT / 'dbt/target/run_results.json').read_text(encoding='utf-8'))
    save_json('dbt_resultados.json', {
        'metadata':artifact['metadata'], 'elapsed_time':artifact['elapsed_time'],
        'command':'dbt build',
        'results':[{'unique_id':r['unique_id'],'status':r['status'],
                    'failures':r.get('failures'),'execution_time':r['execution_time']}
                   for r in artifact['results']],
    })


def apply_constraints():
    with connect('dw') as connection, connection.cursor() as cursor:
        cursor.execute((ROOT / 'sql/02_constraints.sql').read_text(encoding='utf-8'))
    LOG.info('PK, FK y restricciones dimensionales aplicadas')


def validate_analytics():
    with connect('dw') as connection, connection.cursor() as cursor:
        cursor.execute((ROOT / 'sql/03_validaciones.sql').read_text(encoding='utf-8'))
        checks = [dict(zip([c.name for c in cursor.description], row)) for row in cursor.fetchall()]
        save_json('validaciones.json', {'generated_at_utc': datetime.now(timezone.utc), 'checks': checks})
        failures = [check for check in checks if not check['passed']]
        if failures:
            raise ValueError(f'Conciliaciones fallidas: {failures}')
    LOG.info('%s conciliaciones analíticas aprobadas', len(checks))


def export():
    destination = ROOT / 'data/exports'
    destination.mkdir(parents=True, exist_ok=True)
    with connect('dw') as connection, connection.cursor() as cursor:
        cursor.execute("SELECT tablename FROM pg_tables WHERE schemaname = 'marts' ORDER BY tablename")
        names = [row[0] for row in cursor.fetchall()]
        for name in names:
            cursor.execute(sql.SQL('SELECT * FROM marts.{}').format(sql.Identifier(name)))
            with (destination / f'{name}.csv').open('w', encoding='utf-8-sig', newline='') as stream:
                writer = csv.writer(stream)
                writer.writerow([column.name for column in cursor.description])
                writer.writerows(cursor.fetchall())
    LOG.info('%s tablas marts exportadas a CSV', len(names))


def full():
    check_sources()
    load_raw()
    validate_raw()
    run_dbt('build')
    apply_constraints()
    validate_analytics()
    run_dbt('docs generate')
    export()


def main():
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
    commands = {'init-source': init_source, 'check': check_sources, 'load': load_raw, 'validate-raw': validate_raw,
                'constraints': apply_constraints, 'validate': validate_analytics, 'export': export, 'full': full}
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=commands)
    commands[parser.parse_args().command]()


if __name__ == '__main__':
    main()
