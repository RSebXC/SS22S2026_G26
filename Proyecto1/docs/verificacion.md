# Verificación del proyecto


## Qué se comprobó

| Componente | Comprobación | Evidencia |
|---|---|---|
| Fuentes | Extracción desde PostgreSQL real y cinco CSV | `evidence/carga_raw.json` |
| dbt | 31 modelos y 119 pruebas de datos | `evidence/dbt_resultados.json` |
| Conciliaciones | 11 conteos/importes consistentes | `evidence/validaciones.json` |
| Airflow | Ocho operadores ejecutados en modo prueba | `evidence/dag_ejecucion.json` |
| Scheduler | Ocho tareas ejecutadas por LocalExecutor | `evidence/scheduler_ejecucion.json` |
| Datos inválidos | Diez casos detectados sin cambios persistentes | `evidence/casos_calidad.json` |
| Carga atómica | Fallo en última fuente revierte las 12 tablas y auditoría | `evidence/atomicidad.json` |
| Reejecución | Conteos y hashes idénticos en snapshots sucesivos | `evidence/reproducibilidad.json` |
| Modelo físico | 14 PK, 21 FK y cuatro checks en marts | `evidence/resultados_analiticos.json` |
| Lector CSV | Seis pruebas: BOM/CRCRLF, comas, encabezado, campos y vacío | `tests/test_files.py` |

Los resultados de dbt se conservan inmediatamente después de `dbt build`, antes de `dbt docs generate`, para no confundir la compilación de documentación con la ejecución de pruebas.

## Conteos de entrada

| Fuente | Registros |
|---|---:|
| sucursal | 6 |
| categoria | 8 |
| marca | 10 |
| producto | 80 |
| cliente | 250 |
| venta | 1,200 |
| venta_detalle | 3,209 |
| inventario_bodega | 3,840 |
| proveedores_precios | 103 |
| promociones | 30 |
| metas_ventas | 48 |
| devoluciones | 80 |

Los diez ejemplos de `casos_calidad_opcionales.csv` se excluyen de la carga principal. El Excel es un diccionario y no una fuente de hechos adicional.

## Reproducir la verificación

Desde `Proyecto1`, con los servicios iniciados:

```powershell
python -m unittest discover -s tests -v
docker compose run --rm pipeline python -m src.pipeline full
docker compose run --rm pipeline python scripts/verificar_calidad.py
docker compose run --rm pipeline python scripts/verificar_atomicidad.py
docker compose run --rm pipeline python scripts/verificar_dag.py
docker compose run --rm pipeline python scripts/verificar_scheduler.py
docker compose run --rm pipeline python scripts/conservar_documentacion.py
docker compose run --rm pipeline python scripts/reportar_resultados.py
python scripts/generar_graficas.py
```

`verificar_scheduler.py` crea un run identificable, espera al scheduler y vuelve a pausar el DAG al terminar. Al habilitar temporalmente el DAG también puede existir una ejecución programada: `max_active_runs=1` evita que dos corridas se reconstruyan simultáneamente. No ejecutar cargas independientes mientras el scheduler esté trabajando.

La verificación se realizó en el entorno local de Docker. La interfaz de Airflow presentó un healthcheck positivo y las ejecuciones del DAG y del scheduler están registradas en los archivos JSON de evidencia. No se evaluó un despliegue de producción ni un segundo equipo.

## DDL y documentación generada

- `sql/01_raw.sql`: bootstrap raw y auditoría utilizado por Python.
- `sql/02_constraints.sql`: PK/FK/checks idempotentes después de dbt.
- `sql/03_validaciones.sql`: once conciliaciones.
- `sql/04_consultas_analiticas.sql`: ocho consultas de negocio.
- `sql/05_dw_ddl.sql`: DDL real exportado mediante `pg_dump --schema-only --no-owner --no-privileges`, sin datos ni contraseñas.
- `docs/dbt/`: copia del índice, manifest y catálogo de documentación dbt.

`05_dw_ddl.sql` sirve para inspeccionar o reconstruir la estructura en una base vacía; el flujo normal crea raw con Python y transforma el DW con dbt. No ejecutar el DDL exportado sobre las tablas existentes.
