"""Guarda documentación dbt y evidencia regenerable para la entrega."""
import json
import shutil
from datetime import datetime, timezone
from pathlib import Path

from src.pipeline import ROOT, connect, save_json

target = ROOT/'docs/dbt'
target.mkdir(parents=True,exist_ok=True)
for name in ('index.html','manifest.json','catalog.json'):
    shutil.copyfile(ROOT/'dbt/target'/name,target/name)

with connect('dw') as connection, connection.cursor() as cursor:
    cursor.execute('SELECT batch_id,counts,file_hashes FROM audit.load_runs ORDER BY completed_at DESC LIMIT 3')
    snapshots = [dict(zip(['batch_id','counts','file_hashes'],row)) for row in cursor.fetchall()]
    cursor.execute("SELECT schemaname,tablename FROM pg_tables WHERE schemaname IN ('raw','marts','audit') ORDER BY schemaname,tablename")
    tables = [dict(zip(['schema','table'],row)) for row in cursor.fetchall()]
same = len(snapshots)>=2 and all(s['counts']==snapshots[0]['counts'] and s['file_hashes']==snapshots[0]['file_hashes'] for s in snapshots)
save_json('reproducibilidad.json',{'generated_at_utc':datetime.now(timezone.utc),
                                  'snapshots_compared':len(snapshots),'same_counts_and_files':same,
                                  'snapshots':snapshots,'tables':tables})
if not same:
    raise RuntimeError('No se demostraron al menos dos snapshots idénticos')
print('Documentación dbt conservada; reejecución sin duplicados verificada')
