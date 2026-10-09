"""Inicializa metadatos y crea el administrador si no existe."""
import json
import os
import subprocess

subprocess.run(['airflow', 'db', 'migrate'], check=True)
result = subprocess.run(['airflow', 'users', 'list', '--output', 'json'], check=True, capture_output=True, text=True)
# Airflow puede imprimir mensajes de log antes del JSON, o "No data found".
users = None
for index, character in enumerate(result.stdout):
    if character != '[':
        continue
    try:
        candidate, _ = json.JSONDecoder().raw_decode(result.stdout[index:])
    except json.JSONDecodeError:
        continue
    if isinstance(candidate, list):
        users = candidate
        break
if users is None:
    if 'no data found' in result.stdout.lower():
        users = []
    else:
        raise RuntimeError('No se pudo interpretar la lista de usuarios Airflow')
if not any(user.get('username') == 'admin' for user in users):
    subprocess.run([
        'airflow', 'users', 'create', '--username', 'admin', '--firstname', 'Grupo',
        '--lastname', '26', '--role', 'Admin', '--email', 'grupo26@example.invalid',
        '--password', os.environ['AIRFLOW_ADMIN_PASSWORD'],
    ], check=True)
