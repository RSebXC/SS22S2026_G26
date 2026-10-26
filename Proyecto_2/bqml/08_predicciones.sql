-- Predicciones sobre ml_nuevos (noviembre, no vistos al entrenar).

-- Regresión: propina real contra reg_lineal y reg_bt_v1
CREATE OR REPLACE TABLE taxi_p2.pred_regresion AS
SELECT
  b.fila_id,
  b.pickup_datetime,
  b.tip_amount                AS propina_real,
  l.predicted_tip_amount      AS pred_lineal,
  b.predicted_tip_amount      AS pred_boosted,
  b.fare_amount,
  b.trip_distance,
  b.hora,
  b.pickup_location_id
FROM ML.PREDICT(MODEL taxi_p2.reg_bt_v1, TABLE taxi_p2.ml_nuevos) AS b
JOIN (
  SELECT fila_id, predicted_tip_amount
  FROM ML.PREDICT(MODEL taxi_p2.reg_lineal, TABLE taxi_p2.ml_nuevos)
) AS l USING (fila_id);

-- Clasificación: probabilidad de propina alta
CREATE OR REPLACE TABLE taxi_p2.pred_clasificacion AS
SELECT
  fila_id,
  pickup_datetime,
  tip_alta                                                              AS clase_real,
  predicted_tip_alta                                                    AS clase_predicha,
  (SELECT prob FROM UNNEST(predicted_tip_alta_probs) WHERE label = 1)   AS prob_tip_alta,
  fare_amount,
  hora,
  pickup_location_id
FROM ML.PREDICT(MODEL taxi_p2.clf_bt, TABLE taxi_p2.ml_nuevos);

-- Rolling forecast: media diaria real y predicha, con media móvil de 7 días
CREATE OR REPLACE TABLE taxi_p2.rolling_forecast AS
WITH diario AS (
  SELECT
    DATE(pickup_datetime)  AS fecha,
    COUNT(*)               AS viajes,
    AVG(propina_real)      AS real_prom,
    AVG(pred_lineal)       AS lineal_prom,
    AVG(pred_boosted)      AS boosted_prom
  FROM taxi_p2.pred_regresion
  GROUP BY fecha
)
SELECT
  fecha, viajes, real_prom, lineal_prom, boosted_prom,
  AVG(real_prom)    OVER w  AS real_mov7,
  AVG(lineal_prom)  OVER w  AS lineal_mov7,
  AVG(boosted_prom) OVER w  AS boosted_mov7
FROM diario
WINDOW w AS (ORDER BY fecha ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY fecha;

-- Muestra de 10 predicciones
SELECT pickup_datetime, ROUND(fare_amount, 2) AS tarifa, ROUND(propina_real, 2) AS real,
       ROUND(pred_lineal, 2) AS lineal, ROUND(pred_boosted, 2) AS boosted
FROM taxi_p2.pred_regresion
ORDER BY pickup_datetime
LIMIT 10;
