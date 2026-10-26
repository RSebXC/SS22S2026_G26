-- Conexión al dataset público y revisión de estructura y calidad.

-- Esquema
SELECT column_name, data_type
FROM `bigquery-public-data.new_york_taxi_trips.INFORMATION_SCHEMA.COLUMNS`
WHERE table_name = 'tlc_yellow_trips_2022'
ORDER BY ordinal_position;

-- Filas y tamaño según metadatos (no consume bytes)
SELECT table_id, row_count, ROUND(size_bytes / POW(1024, 3), 2) AS size_gb
FROM `bigquery-public-data.new_york_taxi_trips.__TABLES__`
WHERE table_id = 'tlc_yellow_trips_2022';

-- Conteo, rango de fechas y nulos en columnas clave
SELECT
  COUNT(*)                                AS total_viajes,
  MIN(pickup_datetime)                    AS primera_recogida,
  MAX(pickup_datetime)                    AS ultima_recogida,
  COUNTIF(pickup_datetime IS NULL)        AS nulos_pickup,
  COUNTIF(passenger_count IS NULL)        AS nulos_pasajeros,
  COUNTIF(pickup_location_id IS NULL)     AS nulos_zona_origen,
  COUNTIF(dropoff_location_id IS NULL)    AS nulos_zona_destino,
  COUNTIF(tip_amount IS NULL)             AS nulos_propina
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- Viajes por año y mes de recogida (detecta fechas fuera de 2022)
SELECT
  EXTRACT(YEAR FROM pickup_datetime)  AS anio,
  EXTRACT(MONTH FROM pickup_datetime) AS mes,
  COUNT(*)                            AS viajes
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY anio, mes
ORDER BY anio, mes;

-- Registros que la limpieza va a descartar
SELECT
  COUNTIF(dropoff_datetime <= pickup_datetime)                              AS fin_antes_de_inicio,
  COUNTIF(TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) > 180)  AS duracion_mayor_3h,
  COUNTIF(SAFE_CAST(trip_distance AS FLOAT64) <= 0)                          AS distancia_cero_o_neg,
  COUNTIF(SAFE_CAST(trip_distance AS FLOAT64) > 100)                         AS distancia_mayor_100,
  COUNTIF(SAFE_CAST(fare_amount AS FLOAT64) <= 0)                            AS tarifa_cero_o_neg,
  COUNTIF(SAFE_CAST(tip_amount AS FLOAT64) < 0)                              AS propina_negativa,
  COUNTIF(SAFE_CAST(passenger_count AS FLOAT64) NOT BETWEEN 1 AND 6)         AS pasajeros_invalidos
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`;

-- Tipo de pago: las propinas en efectivo no se registran, por eso los
-- modelos se entrenan solo con tarjeta
SELECT
  payment_type,
  COUNT(*)                                            AS viajes,
  ROUND(AVG(SAFE_CAST(tip_amount AS FLOAT64)), 2)      AS propina_promedio,
  ROUND(COUNTIF(SAFE_CAST(tip_amount AS FLOAT64) = 0) / COUNT(*) * 100, 1) AS pct_sin_propina
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
GROUP BY payment_type
ORDER BY viajes DESC;
