# Manual de implementación

## Requisitos

- Docker Desktop ejecutándose con contenedores Linux.
- Docker Compose v2 y Python 3.x en Windows para generar `.env`.
- Puertos locales 55432 (PostgreSQL) y 8081 (Airflow) disponibles.
- Conexión a Internet para la primera descarga y construcción de imágenes.

No es necesario instalar Airflow ni dbt directamente en Windows. Las herramientas del pipeline se ejecutan dentro de contenedores Linux. PostgreSQL conserva los datos en un volumen Docker.

## Primera instalación

Desde la raíz del repositorio, en PowerShell:

```powershell
cd Proyecto1
python scripts/configurar_entorno.py
docker compose build pipeline
docker compose up -d postgres
docker compose run --rm pipeline python -m src.pipeline init-source
docker compose run --rm pipeline python -m src.pipeline full
docker compose up -d airflow-webserver airflow-scheduler
```

El SQL transaccional y los CSV ficticios del curso se incluyen en `data/input/`. El catálogo Excel contiene el diccionario, documentado en `docs/diccionario_datos.md`. Para extraer el ZIP original, usar `python scripts/preparar_datos.py 'C:\ruta\Data-20260930.zip'`; el script verifica nombres y evita sobrescribir una fuente modificada.

El bootstrap conserva una fuente ya inicializada. Nunca volver a ejecutar el SQL original para reiniciar la base: contiene `DROP SCHEMA`. El comando `init-source` utiliza una variante no destructiva.

## Airflow

Abrir **http://localhost:8081**, usuario **admin**. La contraseña está en la variable `AIRFLOW_ADMIN_PASSWORD` del `.env` local. Ese archivo no se entrega ni se sube a Git.

El DAG se llama **sgfood_elt**. Seleccionar el DAG y ejecutar **Trigger DAG** para una corrida manual; habilitar el interruptor si se desea la programación diaria a las 06:00 de Guatemala. Se crea inicialmente pausado y sin ejecuciones históricas automáticas.

Las ocho tareas deben terminar en verde. Las tareas Bash ejecutan `dbt build` y `dbt docs generate`; las tareas Python verifican fuentes, cargan raw, concilian conteos, aplican claves y exportan CSV.

Para una prueba completa desde consola:

```powershell
docker compose run --rm pipeline python scripts/verificar_dag.py
```

Esta prueba usa `airflow dags test`, ejecuta realmente los operadores y guarda `evidence/dag_ejecucion.json`. Para evidenciar la ejecución desde el scheduler, disparar también una corrida manual en la interfaz o usar el procedimiento de verificación documentado en `docs/verificacion.md`.

## Comprobaciones y resultados

```powershell
python -m unittest discover -s tests -v
docker compose run --rm pipeline python scripts/verificar_calidad.py
docker compose run --rm pipeline python scripts/reportar_resultados.py
docker compose run --rm pipeline python scripts/conservar_documentacion.py
python scripts/generar_graficas.py
docker compose exec postgres psql -U sgfood -d sgfood_dw -c 'SELECT * FROM marts.rpt_ventas_mensuales LIMIT 10;'
```

`verificar_calidad.py` requiere una ejecución previa de dbt para usar sus pruebas compiladas. Los diez casos inválidos se prueban dentro de transacciones revertidas, sin dejar datos contaminados.

El CLI permite ejecutar etapas por separado:

```powershell
docker compose run --rm pipeline python -m src.pipeline check
docker compose run --rm pipeline python -m src.pipeline load
docker compose run --rm pipeline python -m src.pipeline validate-raw
docker compose run --rm pipeline /opt/dbt/bin/dbt build --project-dir dbt --profiles-dir dbt
docker compose run --rm pipeline python -m src.pipeline constraints
docker compose run --rm pipeline python -m src.pipeline validate
docker compose run --rm pipeline python -m src.pipeline export
```

Aplicar `constraints` después de cada `dbt build`: los modelos de tabla son reconstruidos y las claves físicas deben volver a aplicarse. Para el flujo normal usar el DAG o el comando `full`, que ya respetan ese orden.

## Conexión con DBeaver

| Campo | Valor |
|---|---|
| Motor | PostgreSQL |
| Host | localhost |
| Puerto | 55432 |
| Base analítica | sgfood_dw |
| Usuario | sgfood |
| Contraseña | POSTGRES_PASSWORD del `.env` |
| Schema analítico | marts |

La base fuente es `sgfood_source`; no usarla para el reporte final. Los CSV exportados se encuentran en `data/exports/` y se regeneran al finalizar el pipeline.

## Documentación dbt

`dbt docs generate` produce `dbt/target/index.html`, `manifest.json` y `catalog.json`. Para navegar el sitio:

```powershell
docker compose run --rm -p 127.0.0.1:8082:8082 pipeline /opt/dbt/bin/dbt docs serve --project-dir dbt --profiles-dir dbt --host 0.0.0.0 --port 8082 --no-browser
```

Abrir http://localhost:8082. El proceso permanece activo hasta detenerlo con Ctrl+C. También se conserva una copia regenerable de la documentación en `docs/dbt/` para la entrega.

Para consultar esa copia sin conectarse a la base, ejecutar `python -m http.server 8082 --bind 127.0.0.1 --directory docs/dbt` y abrir la misma dirección. No abrir directamente `index.html` con `file://`, porque la carga de archivos JSON puede quedar bloqueada por el navegador.

## Detener y retomar

```powershell
docker compose stop
docker compose up -d postgres airflow-webserver airflow-scheduler
```

`stop` conserva las bases y la evidencia. No eliminar volúmenes para detener el proyecto. Si un servicio falla, consultar `docker compose ps` y `docker compose logs --tail 80 NOMBRE_SERVICIO`.

Si se cambia la contraseña en `.env` después de inicializar PostgreSQL, también hay que cambiarla dentro de la base. Volver a generar `.env` no cambia credenciales de un volumen existente.
