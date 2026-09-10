# Diseno e interpretacion del Dashboard VuelosDW

## Fuente de datos

El dashboard utiliza la base de datos dimensional `VuelosDW`, creada a partir
de la Practica 1 y alojada en MySQL 8.4 local. Power BI se conecta al servidor
`127.0.0.1:3306` usando el modo Importar.

La fuente contiene la tabla de hechos `hechos_vuelo` y las dimensiones
`dim_fecha`, `dim_aerolinea`, `dim_aeropuerto`, `dim_pasajero`,
`dim_canal_venta`, `dim_pago` y `dim_cabina`.

## Modelo tabular

El modelo utiliza un esquema estrella. `hechos_vuelo` concentra los registros
de vuelos y sus medidas: precio del ticket, duracion, retraso, equipaje y
estado del vuelo. Las dimensiones permiten segmentar la informacion por fecha,
aerolinea, aeropuerto, pasajero, canal de venta, metodo de pago y clase de
cabina.

Las relaciones son de uno a muchos desde las dimensiones hacia
`hechos_vuelo`, con filtro en una sola direccion. `dim_fecha` se relaciona con
la fecha de salida y la fecha de reserva. `dim_aeropuerto` se relaciona con el
aeropuerto de origen y el aeropuerto de destino. Cuando Power BI deja una de
esas relaciones inactiva, se conserva activa la relacion principal usada por
los visuales de la pagina.

## Pagina implementada: Pagina 1

La pagina presenta un resumen operativo y comercial de los vuelos. Los
elementos implementados son:

- KPI de `Puntualidad` comparado con `Objetivo Puntualidad`, con tendencia por
  fecha.
- Tarjeta de `Total Vuelos`.
- Tarjeta de `Tasa Cancelacion`.
- Tarjeta de `Ingreso Total USD`.
- Grafico circular de `Total Vuelos` por `status`.
- Grafico de lineas de `Total Vuelos` por `anio`.
- Grafico de barras de `Total Vuelos` por `nombre_aerolinea`.
- Segmentadores por anio, aerolinea, estado, canal y clase de cabina.

Los visuales permiten filtrar el resumen y comparar el comportamiento de los
vuelos por los principales atributos operativos y comerciales.

## Medidas utilizadas

La pagina utiliza las medidas DAX creadas en `dax/medidas_dax.md`,
principalmente:

- `Total Vuelos` para medir el volumen de registros.
- `Tasa Cancelacion` para medir la proporcion de vuelos cancelados.
- `Ingreso Total USD` para medir los ingresos por tickets.
- `Puntualidad` para medir el complemento de la tasa de retraso.
- `Objetivo Puntualidad` como referencia del 85% en el KPI.

## Interpretacion

Sin filtros, el modelo contiene 10,000 vuelos y genera USD 770,024.71 en
ingresos. La tasa de cancelacion es 5.60%, por encima del objetivo de 5%.
La puntualidad calculada es aproximadamente 79.13%, por debajo del objetivo
del 85%, por lo que el indicador señala una oportunidad de mejora operativa.

La distribucion de estados muestra 7,278 vuelos `ON_TIME`, 1,970 `DELAYED`,
560 `CANCELLED` y 192 `DIVERTED`. Esta informacion permite identificar la
necesidad de revisar aerolineas, fechas o segmentos con mayor cantidad de
retrasos y cancelaciones.

## Evidencia de la entrega

El archivo `Dashboard_VuelosDW.pdf` contiene la evidencia visual del dashboard.
El archivo `Dashboard_VuelosDW.pbix` contiene la conexion, el modelo, las
medidas DAX, el KPI, los visuales y los segmentadores implementados.
