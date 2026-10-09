"""Ejecuta el DAG real en modo de prueba y registra tareas y estado final."""
import json
import subprocess
from datetime import datetime, timezone
from pathlib import Path

import psycopg2
from src.pipeline import ROOT, save_json
import os

log = ROOT / 'evidence/dag_local.log'
with log.open('w',encoding='utf-8') as stream:
    run = subprocess.run(['airflow','dags','test','sgfood_elt','2026-10-08T06:00:00-06:00'],
                         stdout=stream,stderr=subprocess.STDOUT,text=True)
dsn = os.environ['SOURCE_DSN'].replace('/sgfood_source','/airflow_meta')
with psycopg2.connect(dsn) as connection, connection.cursor() as cursor:
    cursor.execute("SELECT run_id,state,start_date,end_date FROM dag_run WHERE dag_id='sgfood_elt' ORDER BY id DESC LIMIT 1")
    row = cursor.fetchone()
    if row is None:
        raise RuntimeError('No se registró ejecución del DAG; revisar evidence/dag_local.log')
    result = dict(zip(['run_id','state','start_date','end_date'],row))
    cursor.execute("SELECT task_id,state,try_number FROM task_instance WHERE dag_id='sgfood_elt' AND run_id=%s ORDER BY start_date", (result['run_id'],))
    result['tasks'] = [dict(zip(['task_id','state','try_number'],row)) for row in cursor.fetchall()]
result['command_exit_code'] = run.returncode
result['verification_mode'] = 'airflow dags test: ejecución real de operadores; scheduler verificado por separado'
result['generated_at_utc'] = datetime.now(timezone.utc)
save_json('dag_ejecucion.json',result)
print(json.dumps({'state':result['state'],'tasks':len(result['tasks']),'exit_code':run.returncode}))
if run.returncode or result['state'] != 'success' or any(t['state'] != 'success' for t in result['tasks']):
    print(log.read_text(encoding='utf-8')[-8000:])
    raise RuntimeError('DAG fallido; revisar evidence/dag_local.log')
