-- Evaluación con el mismo hold-out temporal (octubre) para comparar los modelos.
-- reg_bt_aleatorio vio parte de octubre al entrenar, por eso su cifra sale optimista.

CREATE OR REPLACE TABLE taxi_p2.eval_regresion AS
SELECT 'reg_lineal' AS modelo, 'CUSTOM temporal' AS split,
       mean_absolute_error AS mae, SQRT(mean_squared_error) AS rmse, r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_lineal, (SELECT * FROM taxi_p2.ml_base WHERE es_eval))
UNION ALL
SELECT 'reg_bt_v1', 'CUSTOM temporal',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_v1, (SELECT * FROM taxi_p2.ml_base WHERE es_eval))
UNION ALL
SELECT 'reg_bt_v2', 'CUSTOM temporal',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_v2, (SELECT * FROM taxi_p2.ml_base WHERE es_eval))
UNION ALL
SELECT 'reg_bt_aleatorio', 'RANDOM 20 %',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_aleatorio, (SELECT * FROM taxi_p2.ml_base WHERE es_eval))
UNION ALL
SELECT 'reg_lineal_tuning', 'CUSTOM temporal',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_lineal_tuning, (SELECT * FROM taxi_p2.ml_base WHERE es_eval))
UNION ALL
SELECT 'reg_bt_tuning', 'CUSTOM temporal',
       mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_tuning, (SELECT * FROM taxi_p2.ml_base WHERE es_eval));

-- Ranking por RMSE
SELECT * FROM taxi_p2.eval_regresion ORDER BY rmse;

-- Evaluación interna de los modelos con split aleatorio
SELECT 'reg_bt_aleatorio' AS modelo, mean_absolute_error AS mae,
       SQRT(mean_squared_error) AS rmse, r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_aleatorio)
UNION ALL
SELECT 'reg_bt_fuga', mean_absolute_error, SQRT(mean_squared_error), r2_score
FROM ML.EVALUATE(MODEL taxi_p2.reg_bt_fuga);

-- Línea base: predecir siempre la media del entrenamiento
WITH media AS (
  SELECT AVG(tip_amount) AS m FROM taxi_p2.ml_base WHERE NOT es_eval
)
SELECT 'linea_base_media' AS modelo,
       AVG(ABS(tip_amount - m))           AS mae,
       SQRT(AVG(POW(tip_amount - m, 2)))  AS rmse
FROM taxi_p2.ml_base, media
WHERE es_eval;

-- Clasificación, umbral 0.5
CREATE OR REPLACE TABLE taxi_p2.eval_clasificacion AS
SELECT 'clf_logistica' AS modelo, accuracy, precision, recall, f1_score, log_loss, roc_auc
FROM ML.EVALUATE(MODEL taxi_p2.clf_logistica, (SELECT * FROM taxi_p2.ml_base WHERE es_eval),
                 STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_bt', accuracy, precision, recall, f1_score, log_loss, roc_auc
FROM ML.EVALUATE(MODEL taxi_p2.clf_bt, (SELECT * FROM taxi_p2.ml_base WHERE es_eval),
                 STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_logistica_tuning', accuracy, precision, recall, f1_score, log_loss, roc_auc
FROM ML.EVALUATE(MODEL taxi_p2.clf_logistica_tuning, (SELECT * FROM taxi_p2.ml_base WHERE es_eval),
                 STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_bt_tuning', accuracy, precision, recall, f1_score, log_loss, roc_auc
FROM ML.EVALUATE(MODEL taxi_p2.clf_bt_tuning, (SELECT * FROM taxi_p2.ml_base WHERE es_eval),
                 STRUCT(0.5 AS threshold));

-- Ranking por ROC-AUC
SELECT * FROM taxi_p2.eval_clasificacion ORDER BY roc_auc DESC;

-- Matrices de confusión (octubre)
CREATE OR REPLACE TABLE taxi_p2.matriz_confusion AS
SELECT 'clf_logistica' AS modelo, expected_label, _0, _1
FROM ML.CONFUSION_MATRIX(MODEL taxi_p2.clf_logistica,
     (SELECT * FROM taxi_p2.ml_base WHERE es_eval), STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_logistica_tuning', expected_label, _0, _1
FROM ML.CONFUSION_MATRIX(MODEL taxi_p2.clf_logistica_tuning,
     (SELECT * FROM taxi_p2.ml_base WHERE es_eval), STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_bt', expected_label, _0, _1
FROM ML.CONFUSION_MATRIX(MODEL taxi_p2.clf_bt,
     (SELECT * FROM taxi_p2.ml_base WHERE es_eval), STRUCT(0.5 AS threshold))
UNION ALL
SELECT 'clf_bt_tuning', expected_label, _0, _1
FROM ML.CONFUSION_MATRIX(MODEL taxi_p2.clf_bt_tuning,
     (SELECT * FROM taxi_p2.ml_base WHERE es_eval), STRUCT(0.5 AS threshold));

SELECT * FROM taxi_p2.matriz_confusion ORDER BY modelo, expected_label;

-- Importancia de variables de reg_bt_v2
CREATE OR REPLACE TABLE taxi_p2.importancia_variables AS
SELECT feature, ROUND(attribution, 4) AS importancia
FROM ML.GLOBAL_EXPLAIN(MODEL taxi_p2.reg_bt_v2);

SELECT * FROM taxi_p2.importancia_variables ORDER BY importancia DESC;

-- Pruebas del ajuste: hiperparámetro y métrica en septiembre (EVAL)
CREATE OR REPLACE TABLE taxi_p2.tuning_regresion AS
SELECT trial_id, hyperparameters.l2_reg AS l2_reg,
       hparam_tuning_evaluation_metrics.r2_score AS r2_eval, eval_loss, status, is_optimal
FROM ML.TRIAL_INFO(MODEL taxi_p2.reg_lineal_tuning);

CREATE OR REPLACE TABLE taxi_p2.tuning_clasificacion AS
SELECT trial_id, hyperparameters.l2_reg AS l2_reg,
       hparam_tuning_evaluation_metrics.roc_auc AS roc_auc_eval, eval_loss, status, is_optimal
FROM ML.TRIAL_INFO(MODEL taxi_p2.clf_logistica_tuning);

-- Pruebas del ajuste en boosted trees
CREATE OR REPLACE TABLE taxi_p2.tuning_bt_regresion AS
SELECT trial_id, hyperparameters.learn_rate AS learn_rate, hyperparameters.max_tree_depth AS max_tree_depth,
       hparam_tuning_evaluation_metrics.r2_score AS r2_eval, eval_loss, status, is_optimal
FROM ML.TRIAL_INFO(MODEL taxi_p2.reg_bt_tuning);

CREATE OR REPLACE TABLE taxi_p2.tuning_bt_clasificacion AS
SELECT trial_id, hyperparameters.learn_rate AS learn_rate, hyperparameters.max_tree_depth AS max_tree_depth,
       hparam_tuning_evaluation_metrics.roc_auc AS roc_auc_eval, eval_loss, status, is_optimal
FROM ML.TRIAL_INFO(MODEL taxi_p2.clf_bt_tuning);
