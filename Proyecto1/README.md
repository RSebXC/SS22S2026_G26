# Proyecto 1: flujo de datos de SG-Food

**Seminario de Sistemas 2, sección N. Grupo 26. USAC.**

Solución ELT para ventas e inventarios con **Python, Apache Airflow, dbt Core y PostgreSQL**. Usa la base transaccional y los CSV ficticios de `Data-20260930.zip`, guarda los datos crudos, construye un modelo dimensional y lo valida con pruebas.

## Integrantes

| Integrante | Carné |
|---|---|
| Rodrigo Sebastian Castro Aguilar | 202204496 |
| César Augusto Francisco Vicente | 202200133 |

Datos de los integrantes registrados en [SS22S2026_G26.pdf](../SS22S2026_G26.pdf), en la raíz del repositorio.

## Qué está implementado

- Extracción de siete tablas desde una base PostgreSQL transaccional y carga de cinco CSV operativos mediante Python.
- Carga raw atómica con metadatos de origen, lote, conteos y hashes; reejecución sin acumular duplicados.
- 12 modelos de staging, dos intermediate y 17 marts: ocho dimensiones, cinco hechos, una tabla puente y tres reportes.
- DAG `sgfood_elt` con ocho tareas, dependencias, reintentos y ejecución diaria a las 06:00 (pausada por defecto).
- Pruebas dbt de unicidad, nulos, relaciones y reglas de negocio; PK/FK físicas y conciliaciones de conteos/importes.
- Verificación de los diez casos inválidos del curso mediante consultas dbt compiladas, dentro de transacciones revertidas.
- DDL del DW, consultas analíticas, documentación dbt, diagramas Mermaid editables y exportaciones CSV.

La [verificación del flujo](docs/verificacion.md) y los [resultados analíticos](docs/resultados.md) documentan las ejecuciones y validaciones realizadas.

## Inicio rápido

Con Docker Desktop abierto, ejecutar desde esta carpeta en PowerShell:

```powershell
python scripts/configurar_entorno.py
docker compose build pipeline
docker compose up -d postgres
docker compose run --rm pipeline python -m src.pipeline init-source
docker compose run --rm pipeline python -m src.pipeline full
docker compose up -d airflow-webserver airflow-scheduler
```

Si el entorno ya está creado, basta con `docker compose up -d postgres airflow-webserver airflow-scheduler`. Abrir **http://localhost:8081**, usuario `admin`, contraseña `AIRFLOW_ADMIN_PASSWORD` del `.env` local. El DAG queda pausado al finalizar la demostración; puede dispararse manualmente o habilitarse para ejecutar a las 06:00 de Guatemala.

**PostgreSQL:** `localhost:55432`, base `sgfood_dw`, usuario `sgfood`, contraseña `POSTGRES_PASSWORD` del `.env`. Las tablas de análisis están en `marts`. Las fuentes y los metadatos de Airflow se mantienen en bases separadas.

## Flujo

```mermaid
flowchart LR
    BD[(PostgreSQL OLTP)] --> PY[Python]
    CSV[5 CSV] --> PY
    PY --> RAW[(raw)]
    RAW --> STG[dbt staging]
    STG --> INT[dbt intermediate]
    INT --> MART[dbt marts]
    MART --> QA[Pruebas y conciliaciones]
    QA --> DOC[Documentación y exportaciones]
    AF[Airflow] -. coordina .-> PY
    AF -. coordina .-> STG
    AF -. coordina .-> QA
```

## DAG de Airflow

DAG `sgfood_elt`, una ejecución activa a la vez y un reintento por tarea:

```mermaid
flowchart LR
    A[verificar_fuentes] --> B[cargar_raw]
    B --> C[validar_raw]
    C --> D[dbt_build]
    D --> E[aplicar_claves]
    E --> F[conciliar_resultados]
    F --> G[dbt_docs]
    G --> H[exportar_marts]
```

| Tarea | Operador | Función |
|---|---|---|
| `verificar_fuentes` | Python | Valida encabezados de los CSV y conexión a las bases |
| `cargar_raw` | Python | Carga atómica de las 12 tablas a `raw` y registra el lote en `audit.load_runs` |
| `validar_raw` | Python | Compara conteos y lote cargados |
| `dbt_build` | Bash | `dbt build`: modelos y pruebas |
| `aplicar_claves` | Python | PK, FK y checks físicos sobre `marts` |
| `conciliar_resultados` | Python | 11 conciliaciones de conteos e importes |
| `dbt_docs` | Bash | `dbt docs generate` |
| `exportar_marts` | Python | Exporta los marts a CSV |

## Data Warehouse

Esquema estrella en `marts`, construido con dbt: 8 dimensiones, 5 tablas de hechos, una tabla puente y 3 reportes. Las capas son `raw` (texto original con metadatos de carga), `staging` (tipado, vistas), `intermediate` (reglas de ventas y devoluciones) y `marts` (tablas). El DDL completo está en [sql/05_dw_ddl.sql](sql/05_dw_ddl.sql) y la justificación del diseño en [docs/arquitectura.md](docs/arquitectura.md).

```mermaid
erDiagram
    DIM_FECHA ||--o{ FACT_VENTAS : fecha
    DIM_PRODUCTO ||--o{ FACT_VENTAS : producto
    DIM_CLIENTE ||--o{ FACT_VENTAS : cliente
    DIM_SUCURSAL ||--o{ FACT_VENTAS : sucursal
    DIM_CANAL ||--o{ FACT_VENTAS : canal
    DIM_PAGO ||--o{ FACT_VENTAS : pago
    DIM_FECHA ||--o{ FACT_INVENTARIO : corte_y_vencimiento
    DIM_PRODUCTO ||--o{ FACT_INVENTARIO : producto
    DIM_SUCURSAL ||--o{ FACT_INVENTARIO : sucursal
    DIM_FECHA ||--o{ FACT_DEVOLUCIONES : fecha_devolucion
    DIM_PRODUCTO ||--o{ FACT_DEVOLUCIONES : producto
    DIM_CLIENTE o|--o{ FACT_DEVOLUCIONES : cliente_origen
    DIM_SUCURSAL o|--o{ FACT_DEVOLUCIONES : sucursal_origen
    DIM_FECHA ||--o{ FACT_METAS : inicio_mes
    DIM_SUCURSAL ||--o{ FACT_METAS : sucursal
    DIM_PRODUCTO ||--o{ FACT_PROVEEDOR_PRECIO : producto
    DIM_PROVEEDOR ||--o{ FACT_PROVEEDOR_PRECIO : proveedor
    DIM_FECHA ||--o{ FACT_PROVEEDOR_PRECIO : vigencia
    FACT_VENTAS ||--o{ BRIDGE_PROMOCION_VENTA : linea_elegible
    DIM_PROMOCION ||--o{ BRIDGE_PROMOCION_VENTA : promocion_potencial
    FACT_VENTAS {
        bigint venta_key PK
        bigint id_venta
        int fecha_key FK
        int producto_key FK
        int cliente_key FK
        int sucursal_key FK
        string canal_key FK
        string pago_key FK
        string estado
        numeric importe_neto_vendido
        numeric margen_estimado
    }
    FACT_INVENTARIO {
        string inventario_key PK
        int fecha_key FK
        int vencimiento_fecha_key FK
        int producto_key FK
        int sucursal_key FK
        string lote
        int stock_disponible
    }
    FACT_DEVOLUCIONES {
        bigint devolucion_key PK
        int fecha_key FK
        int producto_key FK
        int cliente_key FK
        int sucursal_key FK
        boolean es_valida
        numeric importe_devolucion_estimado
    }
    FACT_METAS {
        string meta_key PK
        int fecha_key FK
        int sucursal_key FK
        string periodo
        numeric meta_ventas
    }
    FACT_PROVEEDOR_PRECIO {
        string precio_key PK
        int producto_key FK
        int proveedor_key FK
        int fecha_key FK
        numeric costo_proveedor
    }
```

## Estructura

```text
Proyecto1/
├── README.md, Dockerfile, compose.yaml, .env.example
├── data/input/         # Fuentes originales ficticias del curso
├── data/exports/       # Marts exportados; regenerables
├── src/                # Contratos, lectura y pipeline Python
├── scripts/            # Configuración, verificación y reportes
├── airflow/dags/       # DAG sgfood_elt
├── dbt/
│   ├── models/staging/
│   ├── models/intermediate/
│   ├── models/marts/
│   ├── macros/
│   └── tests/
├── sql/                # Raw, restricciones, conciliaciones, consultas y DDL
├── tests/              # Pruebas del lector CSV
├── evidence/           # Evidencia de ejecución en JSON
└── docs/               # Manual, diseño, diccionario, resultados y Mermaid
```

## Documentación y entrega

- [Manual de implementación](docs/manual_implementacion.md).
- [Arquitectura y justificación](docs/arquitectura.md).
- [Diccionario original](docs/diccionario_datos.md).
- [Resultados y gráficas](docs/resultados.md).
- [Verificación del flujo](docs/verificacion.md).

## Límites del análisis

Las ventas solo cuentan operaciones completadas. El inventario no se suma entre cortes mensuales. Margen, valor de inventario y devolución monetaria se identifican como estimaciones por las limitaciones de los insumos. Las promociones indican elegibilidad por categoría/fecha; no se afirma que hayan causado una venta.
