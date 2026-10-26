-- viajes_std: todos los viajes válidos de 2022, sin optimizar.
-- viajes_opt: mismo contenido con partición mensual por fecha y clustering por zonas.
-- SAFE_CAST porque en el origen varias columnas son NUMERIC o texto.
-- pickup_datetime ya está en hora local de Nueva York.

CREATE OR REPLACE TABLE taxi_p2.viajes_std AS
WITH origen AS (
  SELECT
    pickup_datetime,
    dropoff_datetime,
    SAFE_CAST(SAFE_CAST(passenger_count AS FLOAT64) AS INT64)      AS passenger_count,
    SAFE_CAST(trip_distance AS FLOAT64)                            AS trip_distance,
    SAFE_CAST(SAFE_CAST(rate_code AS FLOAT64) AS INT64)            AS rate_code,
    SAFE_CAST(SAFE_CAST(payment_type AS FLOAT64) AS INT64)         AS payment_type,
    CAST(SAFE_CAST(SAFE_CAST(pickup_location_id AS FLOAT64) AS INT64) AS STRING)  AS pickup_location_id,
    CAST(SAFE_CAST(SAFE_CAST(dropoff_location_id AS FLOAT64) AS INT64) AS STRING) AS dropoff_location_id,
    SAFE_CAST(fare_amount AS FLOAT64)                              AS fare_amount,
    SAFE_CAST(tip_amount AS FLOAT64)                               AS tip_amount,
    SAFE_CAST(tolls_amount AS FLOAT64)                             AS tolls_amount,
    SAFE_CAST(total_amount AS FLOAT64)                             AS total_amount
  FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
),
con_hash AS (
  SELECT
    FARM_FINGERPRINT(CONCAT(
      CAST(pickup_datetime AS STRING), '|', CAST(dropoff_datetime AS STRING), '|',
      pickup_location_id, '|', dropoff_location_id, '|', CAST(fare_amount AS STRING)
    )) AS viaje_hash,
    *
  FROM origen
)
SELECT
  viaje_hash,
  pickup_datetime,
  dropoff_datetime,
  passenger_count,
  trip_distance,
  rate_code,
  payment_type,
  pickup_location_id,
  dropoff_location_id,
  fare_amount,
  tip_amount,
  tolls_amount,
  total_amount,
  EXTRACT(HOUR FROM pickup_datetime)                          AS hora,
  EXTRACT(DAYOFWEEK FROM pickup_datetime)                     AS dia_semana,
  EXTRACT(MONTH FROM pickup_datetime)                         AS mes,
  EXTRACT(DAYOFWEEK FROM pickup_datetime) IN (1, 7)           AS fin_de_semana,
  TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 60.0 AS duracion_min,
  SAFE_DIVIDE(trip_distance,
    TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, SECOND) / 3600.0) AS velocidad_mph
FROM con_hash
WHERE pickup_datetime >= TIMESTAMP '2022-01-01'
  AND pickup_datetime <  TIMESTAMP '2023-01-01'
  AND dropoff_datetime > pickup_datetime
  AND TIMESTAMP_DIFF(dropoff_datetime, pickup_datetime, MINUTE) BETWEEN 1 AND 180
  AND trip_distance BETWEEN 0.1 AND 100
  AND fare_amount > 0 AND fare_amount < 500
  AND tip_amount >= 0
  AND total_amount > 0
  AND passenger_count BETWEEN 1 AND 6
  AND pickup_location_id IS NOT NULL
  AND dropoff_location_id IS NOT NULL;

-- Partición mensual por fecha de recogida y clustering por zonas.
CREATE TABLE taxi_p2.viajes_opt
PARTITION BY TIMESTAMP_TRUNC(pickup_datetime, MONTH)
CLUSTER BY pickup_location_id, dropoff_location_id
AS
SELECT *
FROM taxi_p2.viajes_std;

-- Control: mismas filas en ambas
SELECT 'viajes_std' AS tabla, COUNT(*) AS filas FROM taxi_p2.viajes_std
UNION ALL
SELECT 'viajes_opt', COUNT(*) FROM taxi_p2.viajes_opt;
