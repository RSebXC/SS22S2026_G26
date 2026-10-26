-- Datos para BigQuery ML.
-- Regresión: tip_amount. Clasificación: tip_alta (propina >= 25 % de la tarifa).
-- Solo tarjeta: la propina en efectivo no se registra.
-- Muestra de 1 de cada 20 viajes por hash (reproducible).
-- total_amount se excluye porque incluye la propina.
-- Split temporal: enero a septiembre entrenan, octubre evalúa (es_eval) y noviembre es nuevo.

CREATE OR REPLACE TABLE taxi_p2.ml_base
AS
SELECT
  viaje_hash,
  pickup_datetime,
  tip_amount,
  IF(tip_amount >= 0.25 * fare_amount, 1, 0)  AS tip_alta,
  fare_amount,
  trip_distance,
  duracion_min,
  velocidad_mph,
  passenger_count,
  hora,
  dia_semana,
  fin_de_semana,
  CAST(rate_code AS STRING)                  AS rate_code,
  pickup_location_id,
  dropoff_location_id,
  tolls_amount,
  mes = 10                                   AS es_eval
FROM taxi_p2.viajes_std
WHERE payment_type = 1
  AND tip_amount <= 100
  AND mes <= 10
  AND MOD(ABS(viaje_hash), 20) = 0;

-- Viajes de noviembre para ML.PREDICT (clase hash 4 de 20, distinta de ml_base).
CREATE OR REPLACE TABLE taxi_p2.ml_nuevos
AS
SELECT
  ROW_NUMBER() OVER (ORDER BY pickup_datetime, viaje_hash)  AS fila_id,
  viaje_hash,
  pickup_datetime,
  tip_amount,
  IF(tip_amount >= 0.25 * fare_amount, 1, 0)  AS tip_alta,
  fare_amount,
  trip_distance,
  duracion_min,
  velocidad_mph,
  passenger_count,
  hora,
  dia_semana,
  fin_de_semana,
  CAST(rate_code AS STRING)                  AS rate_code,
  pickup_location_id,
  dropoff_location_id,
  tolls_amount
FROM taxi_p2.viajes_std
WHERE payment_type = 1
  AND tip_amount <= 100
  AND MOD(ABS(viaje_hash), 20) = 4
  AND mes = 11;

-- Tamaño de entrenamiento y evaluación, y balance de la clase
SELECT
  es_eval,
  COUNT(*)                       AS filas,
  ROUND(AVG(tip_amount), 3)      AS propina_prom,
  ROUND(AVG(tip_alta) * 100, 1)  AS pct_tip_alta
FROM taxi_p2.ml_base
GROUP BY es_eval;

-- Control: debe devolver 0
SELECT COUNT(*) AS filas_repetidas
FROM taxi_p2.ml_nuevos n
JOIN taxi_p2.ml_base b USING (viaje_hash);
