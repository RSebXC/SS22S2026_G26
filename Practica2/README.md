# Practica 2: Dashboard y KPIs con Power BI

**Seminario de Sistemas 2 - Universidad de San Carlos de Guatemala**

## Objetivo

Construir un dashboard interactivo en Power BI usando la base de datos dimensional desarrollada en la Practica 1 (`VuelosDW`). El reporte debe apoyar la toma de decisiones sobre operaciones de vuelos, ingresos, cancelaciones, retrasos, comportamiento de pasajeros y canales de venta.

## Base utilizada

La Practica 1 define un modelo estrella para el proceso de vuelos:

- Base de datos: `VuelosDW`
- Tabla de hechos: `hechos_vuelo`
- Dimensiones: `dim_fecha`, `dim_aerolinea`, `dim_aeropuerto`, `dim_pasajero`, `dim_canal_venta`, `dim_pago`, `dim_cabina`
- Fuente original: `Practica1/data/dataset_vuelos_crudo.csv`
- Script de esquema: `Practica1/sql/01_schema.sql`
- Consultas de validacion: `Practica1/sql/02_consultas_analiticas.sql`

El PDF menciona SQL Server en el enunciado, pero la rubrica de conexion y
modelado acepta SQL Server o MySQL. Si SQL Server no inicia, la ruta
recomendada para conservar una base real y verla en DBeaver es MySQL.

## Estructura sugerida de entrega

```text
Practica2/
+-- README.md
+-- Dashboard_VuelosDW.pbix
+-- Dashboard_VuelosDW.pdf
+-- dax/
|   +-- medidas_dax.md
+-- docs/
|   +-- diseno_dashboard.md
+-- sql/
    +-- vistas_powerbi.sql
```

El archivo `.pbix` debe guardarse manualmente desde Power BI Desktop dentro de esta carpeta, por ejemplo:

```text
Practica2/Dashboard_VuelosDW.pbix
```

## Conexion desde Power BI

### Ruta rapida sin SQL Server

Si SQL Server no inicia, se puede entregar la P2 usando el modelo dimensional
exportado a CSV. Ejecutar desde PowerShell, ubicandose en `Practica1`:

```powershell
python .\etl\exportar_powerbi.py
```

Esto crea `Practica1/data/powerbi/` con `hechos_vuelo.csv` y las siete
dimensiones. En Power BI usar **Obtener datos > Texto/CSV**, cargar cada uno de
esos ocho archivos y continuar con las mismas relaciones, jerarquias y medidas
DAX indicadas abajo. Esta alternativa conserva el esquema estrella de la P1;
solo cambia el origen de datos.

Al cargar los archivos, verificar que las consultas queden nombradas
exactamente como el archivo sin `.csv` (`hechos_vuelo`, `dim_fecha`, etc.). Si
Power BI detecta `is_cancelled` como numero entero, no hay problema: las
medidas de cancelacion del archivo DAX filtran por `status`.

En esta modalidad, configurar como activa la relacion de `dim_fecha[id_fecha]`
con `hechos_vuelo[id_fecha_salida]` y la de `dim_aeropuerto[id_aeropuerto]`
con `hechos_vuelo[id_aeropuerto_origen]`. Las relaciones con fecha de reserva y
aeropuerto destino pueden quedar inactivas para usarlas con
`USERELATIONSHIP`.

### Ruta recomendada con MySQL local

La base MySQL se puede crear con los archivos de
[`Practica1/mysql`](../Practica1/mysql/README.md). Ejecutar desde PowerShell:

```powershell
cd Practica1
python -m pip install pymysql
powershell -ExecutionPolicy Bypass -File .\mysql\iniciar_mysql.ps1
python .\mysql\cargar_modelo_mysql.py
```

En DBeaver conectar a `127.0.0.1`, puerto `3306`, base `VuelosDW`, usuario
`root` y password `Vuelos2026!`. En Power BI seleccionar **Obtener datos >
Base de datos MySQL**, usar `127.0.0.1:3306` y cargar las ocho tablas. Si Power
BI solicita el conector de MySQL, instalar MySQL Connector/NET y reiniciar
Power BI Desktop.

### Ruta con SQL Server

1. Abrir Power BI Desktop.
2. Seleccionar **Obtener datos > SQL Server**.
3. Servidor: `localhost\SQLEXPRESS`.
4. Base de datos: `VuelosDW`.
5. Modo recomendado: **Importar**.
6. Seleccionar las tablas:
   - `hechos_vuelo`
   - `dim_fecha`
   - `dim_aerolinea`
   - `dim_aeropuerto`
   - `dim_pasajero`
   - `dim_canal_venta`
   - `dim_pago`
   - `dim_cabina`
7. Cargar los datos y revisar relaciones en la vista de modelo.

## Relaciones del modelo tabular

Crear o validar estas relaciones en Power BI:

| Tabla origen | Columna | Tabla destino | Columna | Cardinalidad | Direccion |
|---|---|---|---|---|---|
| `dim_fecha` | `id_fecha` | `hechos_vuelo` | `id_fecha_salida` | 1:* | Simple |
| `dim_fecha` | `id_fecha` | `hechos_vuelo` | `id_fecha_reserva` | 1:* | Simple |
| `dim_aerolinea` | `id_aerolinea` | `hechos_vuelo` | `id_aerolinea` | 1:* | Simple |
| `dim_aeropuerto` | `id_aeropuerto` | `hechos_vuelo` | `id_aeropuerto_origen` | 1:* | Simple |
| `dim_aeropuerto` | `id_aeropuerto` | `hechos_vuelo` | `id_aeropuerto_destino` | 1:* | Simple |
| `dim_pasajero` | `id_pasajero` | `hechos_vuelo` | `id_pasajero` | 1:* | Simple |
| `dim_canal_venta` | `id_canal` | `hechos_vuelo` | `id_canal` | 1:* | Simple |
| `dim_pago` | `id_pago` | `hechos_vuelo` | `id_pago` | 1:* | Simple |
| `dim_cabina` | `id_cabina` | `hechos_vuelo` | `id_cabina` | 1:* | Simple |

Importante: como `dim_fecha` y `dim_aeropuerto` se usan con dos roles, Power BI puede dejar una relacion activa y otra inactiva si ambas apuntan a la misma dimension. Las medidas del archivo `dax/medidas_dax.md` incluyen ejemplos con `USERELATIONSHIP` para analizar por fecha de reserva u origen/destino cuando aplique.

## Jerarquias recomendadas

- Fecha de salida: `anio > trimestre > mes > fecha`
- Aerolinea: `codigo_aerolinea > nombre_aerolinea`
- Aeropuerto: `codigo_iata`
- Pasajero: `nacionalidad > genero`
- Comercial: `canal > metodo_pago > clase_cabina`

## Paginas sugeridas del dashboard

1. **Resumen ejecutivo**
   - KPIs principales: vuelos, ingresos, ticket promedio, tasa de cancelacion, retraso promedio.
   - Tendencia mensual de vuelos e ingresos.
   - Distribucion por estado del vuelo.

2. **Operacion de vuelos**
   - Vuelos por aerolinea.
   - Top destinos.
   - Retraso promedio por aeropuerto de origen.
   - Filtros por fecha, aerolinea, cabina y estado.

3. **Ingresos y ventas**
   - Ingresos por aerolinea.
   - Ticket promedio por clase de cabina.
   - Distribucion por canal de venta y metodo de pago.

4. **Pasajeros**
   - Distribucion por genero.
   - Vuelos por nacionalidad.
   - Edad promedio por canal o cabina.

## Archivos de apoyo

- [Medidas DAX](dax/medidas_dax.md)
- [Diseno del dashboard](docs/diseno_dashboard.md)
- [Vistas SQL opcionales para SQL Server](sql/vistas_powerbi.sql)

Las vistas SQL son opcionales y solo aplican a la ruta SQL Server. En la ruta
MySQL no son necesarias: Power BI se conecta directamente a las ocho tablas
relacionadas de `VuelosDW`.

## Checklist de entrega

- [x] Archivo `.pbix` guardado en `Practica2/`.
- [x] Conexion local funcional a MySQL y base `VuelosDW`.
- [x] Ocho tablas cargadas en Power BI.
- [x] Relaciones 1:* entre dimensiones y hechos.
- [ ] Jerarquia de fecha creada (`anio > trimestre > nombre_mes > fecha`).
- [x] Al menos tres medidas DAX implementadas.
- [x] KPI de puntualidad con objetivo del 85%.
- [x] Al menos tres visualizaciones interactivas.
- [x] Segmentadores de fecha, aerolinea, estado, canal y cabina.
- [x] PDF de evidencia agregado como `Dashboard_VuelosDW.pdf`.
- [x] Interpretacion escrita de los KPIs y decisiones de diseno.
- [ ] Revisar que el `.pbix` abra con MySQL iniciado en `127.0.0.1:3306`.

El PDF solicita tres entregables principales: el archivo `.pbix`, un informe
tecnico en PDF o README y evidencia del dashboard. En esta entrega, la
evidencia se encuentra en `Dashboard_VuelosDW.pdf`.
