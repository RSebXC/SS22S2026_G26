-- Mismas consultas sobre viajes_std y viajes_opt, con la caché desactivada.
-- Qn_STD / Qn_OPT identifica cada ejecución en el historial de trabajos.

-- Q1: rango de fechas (partición)
-- Q1_STD
SELECT hora, COUNT(*) AS viajes, ROUND(AVG(total_amount), 2) AS total_prom
FROM taxi_p2.viajes_std
WHERE pickup_datetime >= TIMESTAMP '2022-06-01' AND pickup_datetime < TIMESTAMP '2022-06-08'
GROUP BY hora ORDER BY hora;

-- Q1_OPT
SELECT hora, COUNT(*) AS viajes, ROUND(AVG(total_amount), 2) AS total_prom
FROM taxi_p2.viajes_opt
WHERE pickup_datetime >= TIMESTAMP '2022-06-01' AND pickup_datetime < TIMESTAMP '2022-06-08'
GROUP BY hora ORDER BY hora;

-- Q2: una zona de origen (clustering). 132 = aeropuerto JFK.
-- Q2_STD
SELECT dropoff_location_id, COUNT(*) AS viajes, ROUND(AVG(fare_amount), 2) AS tarifa_prom
FROM taxi_p2.viajes_std
WHERE pickup_location_id = '132'
GROUP BY dropoff_location_id ORDER BY viajes DESC LIMIT 10;

-- Q2_OPT
SELECT dropoff_location_id, COUNT(*) AS viajes, ROUND(AVG(fare_amount), 2) AS tarifa_prom
FROM taxi_p2.viajes_opt
WHERE pickup_location_id = '132'
GROUP BY dropoff_location_id ORDER BY viajes DESC LIMIT 10;

-- Q3: un mes y una zona (partición y clustering)
-- Q3_STD
SELECT DATE(pickup_datetime) AS fecha, COUNT(*) AS viajes, ROUND(SUM(total_amount), 0) AS ingresos
FROM taxi_p2.viajes_std
WHERE pickup_datetime >= TIMESTAMP '2022-03-01' AND pickup_datetime < TIMESTAMP '2022-04-01'
  AND pickup_location_id = '132'
GROUP BY fecha ORDER BY fecha;

-- Q3_OPT
SELECT DATE(pickup_datetime) AS fecha, COUNT(*) AS viajes, ROUND(SUM(total_amount), 0) AS ingresos
FROM taxi_p2.viajes_opt
WHERE pickup_datetime >= TIMESTAMP '2022-03-01' AND pickup_datetime < TIMESTAMP '2022-04-01'
  AND pickup_location_id = '132'
GROUP BY fecha ORDER BY fecha;

-- Resumen desde el historial de trabajos
CREATE OR REPLACE TABLE taxi_p2.comparacion_optimizacion AS
SELECT
  REGEXP_EXTRACT(query, '(Q[0-9]_[A-Z]+)')            AS consulta,
  creation_time,
  ROUND(total_bytes_processed / POW(1024, 2), 1)      AS mb_procesados,
  ROUND(total_bytes_billed / POW(1024, 2), 1)         AS mb_facturados,
  TIMESTAMP_DIFF(end_time, start_time, MILLISECOND)   AS ms_transcurridos,
  total_slot_ms                                       AS slot_ms
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
WHERE creation_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
  AND cache_hit IS FALSE
  AND query LIKE '-- Q%'
  AND query NOT LIKE '%INFORMATION_SCHEMA%';

-- Reducción por par (última ejecución de cada consulta)
WITH ult AS (
  SELECT * EXCEPT (rn) FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY consulta ORDER BY creation_time DESC) AS rn
    FROM taxi_p2.comparacion_optimizacion
  )
  WHERE rn = 1
)
SELECT
  SUBSTR(s.consulta, 1, 2)                                             AS par,
  s.mb_procesados                                                      AS mb_std,
  o.mb_procesados                                                      AS mb_opt,
  ROUND((1 - SAFE_DIVIDE(o.mb_procesados, s.mb_procesados)) * 100, 1)  AS reduccion_bytes_pct,
  s.ms_transcurridos                                                   AS ms_std,
  o.ms_transcurridos                                                   AS ms_opt,
  s.slot_ms                                                            AS slot_ms_std,
  o.slot_ms                                                            AS slot_ms_opt
FROM ult s
JOIN ult o ON SUBSTR(s.consulta, 1, 2) = SUBSTR(o.consulta, 1, 2)
WHERE s.consulta LIKE '%STD' AND o.consulta LIKE '%OPT'
ORDER BY par;
