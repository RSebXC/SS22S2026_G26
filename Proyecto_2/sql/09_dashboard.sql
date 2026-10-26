-- Tablas pequeñas para el tablero de Looker Studio.

-- Viajes, ingresos y tarifa promedio por mes
CREATE OR REPLACE TABLE taxi_p2.dash_mensual AS
SELECT
  mes,
  COUNT(*)                      AS viajes,
  ROUND(SUM(total_amount), 0)   AS ingresos,
  ROUND(AVG(fare_amount), 2)    AS tarifa_prom
FROM taxi_p2.viajes_opt
WHERE mes <= 11
GROUP BY mes;

-- Demanda y velocidad por hora, separando laborables de fin de semana
CREATE OR REPLACE TABLE taxi_p2.dash_hora AS
SELECT
  hora,
  IF(fin_de_semana, 'Fin de semana', 'Laborable')  AS tipo_dia,
  COUNT(*)                                         AS viajes,
  ROUND(AVG(velocidad_mph), 1)                     AS velocidad_prom_mph
FROM taxi_p2.viajes_opt
GROUP BY hora, tipo_dia;

-- Porcentaje de propina promedio por rango de distancia (solo tarjeta)
CREATE OR REPLACE TABLE taxi_p2.dash_distancia AS
SELECT
  CASE
    WHEN trip_distance < 1  THEN '1) menos de 1 mi'
    WHEN trip_distance < 3  THEN '2) 1 a 3 mi'
    WHEN trip_distance < 6  THEN '3) 3 a 6 mi'
    WHEN trip_distance < 12 THEN '4) 6 a 12 mi'
    ELSE '5) 12 mi o mas'
  END                                                        AS rango_distancia,
  COUNT(*)                                                   AS viajes,
  ROUND(AVG(SAFE_DIVIDE(tip_amount, fare_amount)) * 100, 1)  AS propina_pct_prom
FROM taxi_p2.viajes_opt
WHERE payment_type = 1
GROUP BY rango_distancia;

-- Tablas con nombres de columna sin acentos ni espacios, para Looker Studio

-- Propina diaria de noviembre: real y predicha, con media móvil de 7 días
CREATE OR REPLACE TABLE taxi_p2.dash_prediccion AS
SELECT
  fecha                          AS Dia,
  ROUND(real_mov7, 3)            AS Propina_real,
  ROUND(lineal_mov7, 3)          AS Modelo_lineal,
  ROUND(boosted_mov7, 3)         AS Modelo_de_arboles
FROM taxi_p2.rolling_forecast;

-- Calidad de los modelos que predicen la propina en dólares
CREATE OR REPLACE TABLE taxi_p2.dash_modelos_regresion AS
SELECT
  CASE modelo
    WHEN 'reg_lineal'        THEN 'Regresión lineal'
    WHEN 'reg_lineal_tuning' THEN 'Regresión lineal ajustada'
    WHEN 'reg_bt_v1'         THEN 'Árboles v1'
    WHEN 'reg_bt_v2'         THEN 'Árboles v2, más profundo'
    WHEN 'reg_bt_tuning'     THEN 'Árboles ajustados'
    WHEN 'reg_bt_aleatorio'  THEN 'Árboles, partición aleatoria'
  END                               AS Modelo,
  ROUND(mae, 2)                     AS Error_medio_USD,
  ROUND(rmse, 2)                    AS Error_tipico_USD,
  ROUND(r2_score * 100, 0)          AS Variacion_explicada_pct
FROM taxi_p2.eval_regresion;

-- Calidad de los modelos que predicen si la propina es alta
CREATE OR REPLACE TABLE taxi_p2.dash_modelos_clasificacion AS
SELECT
  CASE modelo
    WHEN 'clf_logistica'        THEN 'Regresión logística'
    WHEN 'clf_logistica_tuning' THEN 'Regresión logística ajustada'
    WHEN 'clf_bt'               THEN 'Árboles'
    WHEN 'clf_bt_tuning'        THEN 'Árboles ajustados'
  END                               AS Modelo,
  ROUND(accuracy * 100, 1)          AS Aciertos_pct,
  ROUND(f1_score * 100, 1)          AS F1_pct,
  ROUND(roc_auc, 3)                 AS ROC_AUC
FROM taxi_p2.eval_clasificacion;

-- Variables que más pesan en la predicción de la propina
CREATE OR REPLACE TABLE taxi_p2.dash_importancia AS
SELECT
  CASE feature
    WHEN 'fare_amount'         THEN 'Tarifa'
    WHEN 'tolls_amount'        THEN 'Peajes'
    WHEN 'trip_distance'       THEN 'Distancia'
    WHEN 'duracion_min'        THEN 'Duración'
    WHEN 'rate_code'           THEN 'Tipo de tarifa'
    WHEN 'hora'                THEN 'Hora'
    WHEN 'velocidad_mph'       THEN 'Velocidad'
    WHEN 'fin_de_semana'       THEN 'Fin de semana'
    WHEN 'dropoff_location_id' THEN 'Zona de destino'
    WHEN 'pickup_location_id'  THEN 'Zona de origen'
    WHEN 'dia_semana'          THEN 'Día de la semana'
    WHEN 'passenger_count'     THEN 'Pasajeros'
    ELSE feature
  END                               AS Variable,
  importancia                       AS Importancia
FROM taxi_p2.importancia_variables;

-- Aciertos y errores de los clasificadores sobre octubre
CREATE OR REPLACE TABLE taxi_p2.dash_matriz AS
SELECT
  CASE modelo
    WHEN 'clf_logistica'        THEN 'Regresión logística'
    WHEN 'clf_logistica_tuning' THEN 'Regresión logística ajustada'
    WHEN 'clf_bt'               THEN 'Árboles'
    WHEN 'clf_bt_tuning'        THEN 'Árboles ajustados'
  END                                           AS Modelo,
  IF(expected_label = 1, 'Propina alta', 'Propina baja')  AS Caso_real,
  CAST(_0 AS INT64)                             AS Predijo_propina_baja,
  CAST(_1 AS INT64)                             AS Predijo_propina_alta
FROM taxi_p2.matriz_confusion;

-- Viajes por mes
CREATE OR REPLACE TABLE taxi_p2.dash_viajes_mes AS
SELECT DATE(2022, mes, 1) AS Mes, viajes AS Viajes
FROM taxi_p2.dash_mensual;

-- Viajes por hora del día
CREATE OR REPLACE TABLE taxi_p2.dash_viajes_hora AS
SELECT hora AS Hora_del_dia, tipo_dia AS Tipo_de_dia, viajes AS Viajes
FROM taxi_p2.dash_hora;

-- Propina según la distancia del viaje
CREATE OR REPLACE TABLE taxi_p2.dash_propina_distancia AS
SELECT
  CASE SUBSTR(rango_distancia, 1, 1)
    WHEN '1' THEN 'Menos de 1 milla'
    WHEN '2' THEN 'De 1 a 3 millas'
    WHEN '3' THEN 'De 3 a 6 millas'
    WHEN '4' THEN 'De 6 a 12 millas'
    ELSE 'Más de 12 millas'
  END                                       AS Distancia_del_viaje,
  CAST(SUBSTR(rango_distancia, 1, 1) AS INT64)  AS Orden,
  ROUND(propina_pct_prom, 1)                AS Propina_pct_de_tarifa
FROM taxi_p2.dash_distancia;
