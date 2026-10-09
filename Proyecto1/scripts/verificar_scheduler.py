"""Dispara una ejecución y verifica que el scheduler complete sus tareas."""
import json
import os
import subprocess
import time
from datetime import datetime, timezone

import psycopg2
from src.pipeline import save_json

run_id = 'verificacion_scheduler_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
dsn = os.environ['SOURCE_DSN'].replace('/sgfood_source','/airflow_meta')
deadline = time.monotonic() + 180


def cli(*args):
    result = subprocess.run(['airflow','dags',*args],capture_output=True,text=True)
    if result.returncode:
        raise RuntimeError(result.stdout[-2000:] + result.stderr[-2000:])


cli('trigger','--run-id',run_id,'sgfood_elt')
cli('unpause','sgfood_elt')
try:
    while time.monotonic() < deadline:
        with psycopg2.connect(dsn) as connection, connection.cursor() as cursor:
            cursor.execute('SELECT state,start_date,end_date FROM dag_run WHERE dag_id=%s AND run_id=%s',('sgfood_elt',run_id))
            row = cursor.fetchone()
            if row and row[0] in ('success','failed'):
                result = dict(zip(['state','start_date','end_date'],row))
                cursor.execute('SELECT task_id,state,try_number FROM task_instance WHERE dag_id=%s AND run_id=%s ORDER BY start_date',('sgfood_elt',run_id))
                result['tasks'] = [dict(zip(['task_id','state','try_number'],r)) for r in cursor.fetchall()]
                result['run_id'] = run_id
                result['verification_mode'] = 'scheduler + LocalExecutor; ejecución disparada mediante CLI'
                result['generated_at_utc'] = datetime.now(timezone.utc)
                save_json('scheduler_ejecucion.json',result)
                print(json.dumps({'state':result['state'],'tasks':len(result['tasks']),'run_id':run_id}))
                if result['state'] != 'success' or any(t['state']!='success' for t in result['tasks']):
                    raise RuntimeError('Ejecución del scheduler fallida')
                break
        time.sleep(2)
    else:
        raise TimeoutError('El scheduler no terminó en 180 segundos')
finally:
    # La demostración no deja activa la programación diaria.
    cli('pause','sgfood_elt')
