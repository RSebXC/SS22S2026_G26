# Variables, etiquetas y partición de datos

## Problemas de modelado

| Problema | Etiqueta | Tipo | Propósito |
|---|---|---|---|
| Regresión | `tip_amount` | numérica | Estimar la propina de un viaje pagado con tarjeta |
| Clasificación | `tip_alta` (1 si la propina es al menos 25 % de `fare_amount`) | binaria | Identificar viajes con propina alta |

La población son los viajes de 2022 pagados con tarjeta (`payment_type = 1`). Las propinas en efectivo no se registran en el dataset y aparecen en 0.

## Variables de entrada

| Variable | Origen | Motivo |
|---|---|---|
| `fare_amount` | original | La propina suele ser proporcional a la tarifa |
| `trip_distance` | original | Los viajes largos tienen otras tarifas y hábitos de propina |
| `duracion_min` | fin menos inicio | El tráfico alarga el viaje sin cambiar la distancia |
| `velocidad_mph` | distancia entre duración | Separa tráfico congestionado de trayectos en autopista |
| `hora` | de `pickup_datetime` | La propina cambia entre hora pico, noche y madrugada |
| `dia_semana`, `fin_de_semana` | de `pickup_datetime` | Días laborables frente a ocio |
| `passenger_count` | original | Grupos grandes reparten la cuenta distinto |
| `rate_code` | original | Las tarifas fijas (aeropuertos) tienen comportamiento propio |
| `pickup_location_id`, `dropoff_location_id` | original | Efecto geográfico: negocios, turismo, aeropuertos |
| `tolls_amount` | original | Se cobra durante el viaje y se asocia a trayectos largos |

`tip_alta` se define con `fare_amount`, que también es variable de entrada. No hay fuga porque la tarifa se conoce antes de la propina y no la contiene.

## Variables excluidas por fuga de información

| Variable | Motivo |
|---|---|
| `total_amount` | Es tarifa más extras más propina; el modelo recuperaría la etiqueta por resta. `reg_bt_fuga` lo demuestra. |
| `payment_type` | Es constante en la muestra (solo tarjeta) |
| `viaje_hash`, `pickup_datetime` | Sirven para el split y la identificación, no como entrada |

## Partición de datos

| Método | Modelos | Justificación |
|---|---|---|
| `CUSTOM` con `es_eval` (octubre evalúa, enero a septiembre entrenan) | `reg_lineal`, `reg_bt_v1`, `reg_bt_v2`, `clf_logistica`, `clf_bt` | Simula el uso real: se predice un periodo posterior al entrenamiento y no se mezclan fechas |
| `CUSTOM` con `conjunto` (enero a agosto TRAIN, septiembre EVAL, octubre TEST) | `reg_lineal_tuning`, `clf_logistica_tuning`, `reg_bt_tuning`, `clf_bt_tuning` | El ajuste automático exige una columna TRAIN / EVAL / TEST: septiembre elige hiperparámetros y octubre sigue siendo la prueba final |
| `RANDOM` con `data_split_eval_fraction = 0.2` | `reg_bt_aleatorio`, `reg_bt_fuga` | Contraste con el método temporal |
| Viajes nuevos (`ml_nuevos`) | `ML.PREDICT` | Noviembre, fuera de la muestra de modelado; la tabla de origen no trae diciembre |

La evaluación de todos los modelos usa el mismo hold-out temporal.

## Limpieza (tabla `viajes_std`)

- Recogida entre el 2022-01-01 y el 2022-12-31
- Fin posterior al inicio y duración de 1 a 180 minutos
- Distancia de 0,1 a 100 millas
- Tarifa mayor que 0 y menor que 500, propina no negativa, total positivo
- Pasajeros de 1 a 6; zonas de origen y destino presentes
