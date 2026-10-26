-- Un CREATE MODEL por modelo; ejecutar por separado.
-- Con split CUSTOM, es_eval = TRUE evalúa y FALSE entrena; no es variable de entrada.

-- Regresión lineal
CREATE OR REPLACE MODEL taxi_p2.reg_lineal
OPTIONS (
  model_type = 'linear_reg',
  input_label_cols = ['tip_amount'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  l2_reg = 0.1
) AS
SELECT
  tip_amount, es_eval,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Boosted trees, configuración pequeña
CREATE OR REPLACE MODEL taxi_p2.reg_bt_v1
OPTIONS (
  model_type = 'boosted_tree_regressor',
  input_label_cols = ['tip_amount'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  max_iterations = 30,
  max_tree_depth = 4,
  learn_rate = 0.3
) AS
SELECT
  tip_amount, es_eval,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Boosted trees, más iteraciones y profundidad, menor tasa de aprendizaje
CREATE OR REPLACE MODEL taxi_p2.reg_bt_v2
OPTIONS (
  model_type = 'boosted_tree_regressor',
  input_label_cols = ['tip_amount'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  max_iterations = 100,
  max_tree_depth = 8,
  learn_rate = 0.1,
  subsample = 0.8,
  enable_global_explain = TRUE
) AS
SELECT
  tip_amount, es_eval,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Igual a reg_bt_v2 con split aleatorio de 20 %, para contrastar con el temporal
CREATE OR REPLACE MODEL taxi_p2.reg_bt_aleatorio
OPTIONS (
  model_type = 'boosted_tree_regressor',
  input_label_cols = ['tip_amount'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  max_iterations = 100,
  max_tree_depth = 8,
  learn_rate = 0.1,
  subsample = 0.8
) AS
SELECT
  tip_amount,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Fuga deliberada: total_amount incluye la propina. Solo para mostrar el efecto.
CREATE OR REPLACE MODEL taxi_p2.reg_bt_fuga
OPTIONS (
  model_type = 'boosted_tree_regressor',
  input_label_cols = ['tip_amount'],
  data_split_method = 'RANDOM',
  data_split_eval_fraction = 0.2,
  max_iterations = 30,
  max_tree_depth = 6
) AS
SELECT
  b.tip_amount,
  v.total_amount,
  b.fare_amount, b.trip_distance, b.duracion_min, b.hora, b.dia_semana,
  b.pickup_location_id, b.dropoff_location_id
FROM taxi_p2.ml_base b
JOIN taxi_p2.viajes_std v
  ON v.viaje_hash = b.viaje_hash
 AND v.pickup_datetime = b.pickup_datetime;

-- Clasificación: regresión logística
CREATE OR REPLACE MODEL taxi_p2.clf_logistica
OPTIONS (
  model_type = 'logistic_reg',
  input_label_cols = ['tip_alta'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  l2_reg = 0.1,
  max_iterations = 20
) AS
SELECT
  tip_alta, es_eval,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Clasificación: boosted trees
CREATE OR REPLACE MODEL taxi_p2.clf_bt
OPTIONS (
  model_type = 'boosted_tree_classifier',
  input_label_cols = ['tip_alta'],
  data_split_method = 'CUSTOM',
  data_split_col = 'es_eval',
  max_iterations = 60,
  max_tree_depth = 6,
  learn_rate = 0.2,
  subsample = 0.8
) AS
SELECT
  tip_alta, es_eval,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Ajuste automático (NUM_TRIALS): exige una columna TRAIN / EVAL / TEST.
-- Enero a agosto entrenan, septiembre elige hiperparámetros, octubre prueba.
CREATE OR REPLACE MODEL taxi_p2.reg_lineal_tuning
OPTIONS (
  model_type = 'linear_reg',
  input_label_cols = ['tip_amount'],
  data_split_method = 'CUSTOM',
  data_split_col = 'conjunto',
  num_trials = 4,
  max_parallel_trials = 2,
  l2_reg = HPARAM_CANDIDATES([0, 0.1, 1, 10])
) AS
SELECT
  tip_amount,
  CASE
    WHEN EXTRACT(MONTH FROM pickup_datetime) <= 8 THEN 'TRAIN'
    WHEN EXTRACT(MONTH FROM pickup_datetime) = 9  THEN 'EVAL'
    ELSE 'TEST'
  END AS conjunto,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

CREATE OR REPLACE MODEL taxi_p2.clf_logistica_tuning
OPTIONS (
  model_type = 'logistic_reg',
  input_label_cols = ['tip_alta'],
  data_split_method = 'CUSTOM',
  data_split_col = 'conjunto',
  num_trials = 4,
  max_parallel_trials = 2,
  l2_reg = HPARAM_CANDIDATES([0.1, 1, 10, 100]),
  max_iterations = 20
) AS
SELECT
  tip_alta,
  CASE
    WHEN EXTRACT(MONTH FROM pickup_datetime) <= 8 THEN 'TRAIN'
    WHEN EXTRACT(MONTH FROM pickup_datetime) = 9  THEN 'EVAL'
    ELSE 'TEST'
  END AS conjunto,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

-- Ajuste en boosted trees: 4 pruebas de tasa de aprendizaje y profundidad.
CREATE OR REPLACE MODEL taxi_p2.reg_bt_tuning
OPTIONS (
  model_type = 'boosted_tree_regressor',
  input_label_cols = ['tip_amount'],
  data_split_method = 'CUSTOM',
  data_split_col = 'conjunto',
  num_trials = 4,
  max_parallel_trials = 2,
  max_iterations = 30,
  learn_rate = HPARAM_CANDIDATES([0.1, 0.3]),
  max_tree_depth = HPARAM_CANDIDATES([4, 6])
) AS
SELECT
  tip_amount,
  CASE
    WHEN EXTRACT(MONTH FROM pickup_datetime) <= 8 THEN 'TRAIN'
    WHEN EXTRACT(MONTH FROM pickup_datetime) = 9  THEN 'EVAL'
    ELSE 'TEST'
  END AS conjunto,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;

CREATE OR REPLACE MODEL taxi_p2.clf_bt_tuning
OPTIONS (
  model_type = 'boosted_tree_classifier',
  input_label_cols = ['tip_alta'],
  data_split_method = 'CUSTOM',
  data_split_col = 'conjunto',
  num_trials = 4,
  max_parallel_trials = 2,
  max_iterations = 30,
  learn_rate = HPARAM_CANDIDATES([0.1, 0.3]),
  max_tree_depth = HPARAM_CANDIDATES([4, 6])
) AS
SELECT
  tip_alta,
  CASE
    WHEN EXTRACT(MONTH FROM pickup_datetime) <= 8 THEN 'TRAIN'
    WHEN EXTRACT(MONTH FROM pickup_datetime) = 9  THEN 'EVAL'
    ELSE 'TEST'
  END AS conjunto,
  fare_amount, trip_distance, duracion_min, velocidad_mph, passenger_count,
  hora, dia_semana, fin_de_semana, rate_code,
  pickup_location_id, dropoff_location_id, tolls_amount
FROM taxi_p2.ml_base;
