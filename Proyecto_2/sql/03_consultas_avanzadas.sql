-- Análisis exploratorio sobre viajes_opt.

-- Métricas descriptivas globales
SELECT
  COUNT(*)                                       AS viajes,
  ROUND(AVG(trip_distance), 2)                   AS distancia_prom_mi,
  ROUND(AVG(duracion_min), 1)                    AS duracion_prom_min,
  ROUND(AVG(fare_amount), 2)                     AS tarifa_prom,
  ROUND(AVG(tip_amount), 2)                      AS propina_prom,
  ROUND(STDDEV(tip_amount), 2)                   AS propina_desv,
  APPROX_QUANTILES(tip_amount, 100)[OFFSET(50)]  AS propina_mediana,
  APPROX_QUANTILES(tip_amount, 100)[OFFSET(95)]  AS propina_p95,
  ROUND(SUM(total_amount) / 1e6, 1)              AS ingresos_millones
FROM taxi_p2.viajes_opt;

-- Viajes e ingresos por mes
SELECT
  mes,
  COUNT(*)                     AS viajes,
  ROUND(SUM(total_amount), 0)  AS ingresos,
  ROUND(AVG(fare_amount), 2)   AS tarifa_prom
FROM taxi_p2.viajes_opt
GROUP BY mes
ORDER BY mes;

-- Demanda por hora, días laborables frente a fin de semana
SELECT
  hora,
  fin_de_semana,
  COUNT(*)                      AS viajes,
  ROUND(AVG(velocidad_mph), 1)  AS velocidad_prom_mph,
  ROUND(AVG(fare_amount), 2)    AS tarifa_prom
FROM taxi_p2.viajes_opt
GROUP BY hora, fin_de_semana
ORDER BY fin_de_semana, hora;

-- Día de la semana (1 = domingo): viajes y propina promedio con tarjeta
SELECT
  dia_semana,
  COUNT(*)                                                 AS viajes,
  ROUND(AVG(IF(payment_type = 1, tip_amount, NULL)), 2)  AS propina_prom_tarjeta
FROM taxi_p2.viajes_opt
GROUP BY dia_semana
ORDER BY dia_semana;

-- Tipo de pago: 1 tarjeta, 2 efectivo, 3 sin cargo, 4 disputa, 5 desconocido
SELECT
  payment_type,
  COUNT(*)                                            AS viajes,
  ROUND(COUNT(*) / SUM(COUNT(*)) OVER () * 100, 2)    AS porcentaje,
  ROUND(AVG(tip_amount), 2)                           AS propina_prom
FROM taxi_p2.viajes_opt
GROUP BY payment_type
ORDER BY viajes DESC;

-- Zonas de origen con más viajes (nombres desde la tabla pública de zonas)
WITH zonas AS (
  SELECT CAST(SAFE_CAST(zone_id AS INT64) AS STRING) AS zona_id, zone_name, borough
  FROM `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
)
SELECT
  v.pickup_location_id,
  z.zone_name,
  z.borough,
  COUNT(*)                                                   AS viajes,
  ROUND(AVG(v.fare_amount), 2)                               AS tarifa_prom,
  ROUND(AVG(IF(v.payment_type = 1, v.tip_amount, NULL)), 2)  AS propina_prom_tarjeta
FROM taxi_p2.viajes_opt v
LEFT JOIN zonas z ON z.zona_id = v.pickup_location_id
GROUP BY v.pickup_location_id, z.zone_name, z.borough
ORDER BY viajes DESC
LIMIT 15;

-- Rutas más frecuentes
WITH zonas AS (
  SELECT CAST(SAFE_CAST(zone_id AS INT64) AS STRING) AS zona_id, zone_name
  FROM `bigquery-public-data.new_york_taxi_trips.taxi_zone_geom`
)
SELECT
  zo.zone_name                       AS origen,
  zd.zone_name                       AS destino,
  COUNT(*)                           AS viajes,
  ROUND(AVG(v.trip_distance), 2)     AS distancia_prom,
  ROUND(AVG(v.total_amount), 2)      AS total_prom
FROM taxi_p2.viajes_opt v
LEFT JOIN zonas zo ON zo.zona_id = v.pickup_location_id
LEFT JOIN zonas zd ON zd.zona_id = v.dropoff_location_id
GROUP BY origen, destino
ORDER BY viajes DESC
LIMIT 20;

-- Porcentaje de propina según distancia (solo tarjeta)
SELECT
  CASE
    WHEN trip_distance < 1  THEN '1) menos de 1 mi'
    WHEN trip_distance < 3  THEN '2) 1 a 3 mi'
    WHEN trip_distance < 6  THEN '3) 3 a 6 mi'
    WHEN trip_distance < 12 THEN '4) 6 a 12 mi'
    ELSE '5) 12 mi o más'
  END                                                       AS rango_distancia,
  COUNT(*)                                                  AS viajes,
  ROUND(AVG(SAFE_DIVIDE(tip_amount, fare_amount)) * 100, 1) AS propina_pct_prom
FROM taxi_p2.viajes_opt
WHERE payment_type = 1
GROUP BY rango_distancia
ORDER BY rango_distancia;

-- Viajes diarios con promedio móvil de 7 días
WITH diario AS (
  SELECT DATE(pickup_datetime) AS fecha, COUNT(*) AS viajes
  FROM taxi_p2.viajes_opt
  GROUP BY fecha
)
SELECT
  fecha,
  viajes,
  ROUND(AVG(viajes) OVER (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 0) AS prom_movil_7d
FROM diario
ORDER BY fecha;
