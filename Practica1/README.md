# Práctica 1 ETL con Python: de dataset crudo a tabla relacional lista para análisis

**Seminario de Sistemas 2 - Universidad de San Carlos de Guatemala**

## Descripción

Proceso ETL en Python que toma un dataset crudo de vuelos (10,000 registros, con problemas reales de calidad: fechas en formatos mixtos, texto con casing inconsistente, valores nulos genuinos, precios con separador decimal mixto) y lo transforma en un **modelo dimensional de esquema estrella** en SQL Server, listo para consultas analíticas de inteligencia de negocios.

## Estructura del repositorio

```
Practica1/
├── README.md                          # este archivo
├── requirements.txt                   # dependencias de Python
├── .env.example / .env                # configuración de conexión a SQL Server
├── data/
│   └── dataset_vuelos_crudo.csv       # fuente cruda (10,000 filas)
├── sql/
│   ├── 01_schema.sql                  # DDL del modelo dimensional (idempotente)
│   └── 02_consultas_analiticas.sql    # consultas de validación e indicadores
├── etl/
│   └── etl_vuelos.ipynb               # notebook ETL
└── docs/
    ├── modelo_dimensional.md          # diseño del esquema
    └── modelo_dimensional.png         # diagrama del modelo
```

## Cómo ejecutar (todo local, sin dependencias externas)

Requisitos ya verificados en este entorno: **Python 3.10+**, **SQL Server** corriendo localmente (instancia `SQLEXPRESS`), driver **ODBC Driver 18 for SQL Server**.

```bash
pip install -r requirements.txt
```

Luego abrir `etl/etl_vuelos.ipynb` (en VS Code con la extensión Jupyter, o con `jupyter lab`) y ejecutar todas las celdas ("Run All"). El notebook es **idempotente**: limpia las tablas antes de recargar, así que se puede volver a correr las veces que sea necesario durante la presentación sin errores de llave duplicada.

El notebook, en orden:
1. Extrae el CSV crudo y muestra su estado inicial.
2. Perfila los problemas de calidad reales encontrados (nulos, formatos de fecha mixtos, casing inconsistente, etc.).
3. Transforma los datos y construye las dimensiones y la tabla de hechos.
4. Muestra el diagrama del modelo dimensional embebido.
5. Ejecuta `sql/01_schema.sql` y carga el modelo completo a SQL Server (`VuelosDW`).
6. Ejecuta `sql/02_consultas_analiticas.sql` y muestra los resultados como validación final.

### Alternativa: correr el schema y las consultas directamente en SSMS

`sql/01_schema.sql` y `sql/02_consultas_analiticas.sql` también se pueden abrir y ejecutar directamente en **SQL Server Management Studio** conectando a `localhost\SQLEXPRESS`, como respaldo independiente del notebook.

## Modelo de datos

Esquema estrella con tabla de hechos `hechos_vuelo` y 7 dimensiones (`dim_fecha`, `dim_aerolinea`, `dim_aeropuerto`, `dim_pasajero`, `dim_canal_venta`, `dim_pago`, `dim_cabina`). Ver [`docs/modelo_dimensional.md`](docs/modelo_dimensional.md) para el diagrama completo y la justificación de cada decisión de diseño y limpieza de datos.

## Resultados de la última carga verificada

| Tabla | Filas |
|---|---|
| `hechos_vuelo` | 10,000 |
| `dim_pasajero` | 10,000 |
| `dim_fecha` | 861 |
| `dim_aerolinea` | 12 |
| `dim_aeropuerto` | 15 |
| `dim_canal_venta` | 6 |
| `dim_pago` | 5 |
| `dim_cabina` | 4 |

Las 10,000 filas del CSV fuente se cargaron íntegramente en `hechos_vuelo` (validado con `SELECT COUNT(*)` y con las consultas de `02_consultas_analiticas.sql`).

## Herramientas utilizadas

- **Python** (pandas, SQLAlchemy, pyodbc, python-dotenv) para el proceso ETL.
- **SQL Server** para el modelo dimensional y las consultas analíticas.
- **Jupyter Notebook** (vía VS Code) como panel de control único.
- **SSMS** como respaldo opcional para inspeccionar la base directamente.
