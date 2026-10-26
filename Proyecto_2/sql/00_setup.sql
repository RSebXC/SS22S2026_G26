-- Dataset propio en US, la misma ubicación del dataset público.
-- Las consultas usan taxi_p2.tabla y resuelven contra el proyecto activo.
CREATE SCHEMA IF NOT EXISTS taxi_p2
OPTIONS (location = 'US');
