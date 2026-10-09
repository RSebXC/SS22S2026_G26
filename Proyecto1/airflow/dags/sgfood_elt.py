"""DAG de SG-Food: Python -> raw -> dbt -> integridad -> documentación."""
from datetime import timedelta

import pendulum
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

from src.pipeline import (
    apply_constraints, check_sources, export, load_raw,
    validate_analytics, validate_raw,
)

with DAG(
    dag_id='sgfood_elt',
    description='ELT de ventas e inventarios del grupo 26',
    start_date=pendulum.datetime(2026, 10, 1, tz='America/Guatemala'),
    schedule='0 6 * * *',
    catchup=False,
    max_active_runs=1,
    default_args={'owner': 'grupo26', 'retries': 1, 'retry_delay': timedelta(minutes=1)},
    tags=['proyecto1', 'sgfood', 'elt'],
    doc_md='''Flujo reproducible con snapshot raw atómico, modelos y pruebas dbt,
    restricciones físicas, conciliaciones y documentación. Los CSV de casos
    inválidos no se cargan en la corrida principal. Ver docs/arquitectura.md.''',
) as dag:
    check = PythonOperator(task_id='verificar_fuentes', python_callable=check_sources)
    load = PythonOperator(task_id='cargar_raw', python_callable=load_raw)
    raw = PythonOperator(task_id='validar_raw', python_callable=validate_raw)
    build = BashOperator(task_id='dbt_build', bash_command='/opt/dbt/bin/dbt build --project-dir /opt/project/dbt --profiles-dir /opt/project/dbt && python /opt/project/scripts/guardar_dbt_resultados.py')
    constraints = PythonOperator(task_id='aplicar_claves', python_callable=apply_constraints)
    validation = PythonOperator(task_id='conciliar_resultados', python_callable=validate_analytics)
    docs = BashOperator(task_id='dbt_docs', bash_command='/opt/dbt/bin/dbt docs generate --project-dir /opt/project/dbt --profiles-dir /opt/project/dbt')
    exports = PythonOperator(task_id='exportar_marts', python_callable=export)
    check >> load >> raw >> build >> constraints >> validation >> docs >> exports
