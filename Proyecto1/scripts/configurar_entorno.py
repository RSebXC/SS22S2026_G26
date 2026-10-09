"""Genera credenciales locales de desarrollo sin sobrescribir .env."""
import base64
import secrets
from pathlib import Path

root = Path(__file__).resolve().parents[1]
target = root / '.env'
if target.exists():
    print('.env existente conservado')
else:
    target.write_text(
        f'POSTGRES_PASSWORD={secrets.token_hex(16)}\n'
        f'AIRFLOW_ADMIN_PASSWORD={secrets.token_hex(12)}\n'
        f'AIRFLOW_SECRET_KEY={secrets.token_hex(32)}\n'
        f'AIRFLOW_FERNET_KEY={base64.urlsafe_b64encode(secrets.token_bytes(32)).decode()}\n',
        encoding='utf-8',
    )
    print('.env creado; credenciales locales excluidas de Git')
