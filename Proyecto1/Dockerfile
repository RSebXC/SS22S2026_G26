FROM apache/airflow:2.11.2-python3.12

USER root
RUN python -m venv /opt/dbt && chown -R airflow:root /opt/dbt
USER airflow
RUN pip install --no-cache-dir "apache-airflow==2.11.2" "psycopg2-binary==2.9.10" \
    && /opt/dbt/bin/pip install --no-cache-dir "dbt-core==1.10.13" "dbt-postgres==1.9.1"
WORKDIR /opt/project
