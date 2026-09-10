USE VuelosDW;
GO

-- Vistas opcionales para facilitar validaciones y tablas resumen en Power BI.
-- No reemplazan el modelo estrella; solo sirven como apoyo de consulta.

CREATE OR ALTER VIEW vw_powerbi_resumen_vuelos AS
SELECT
    COUNT(*) AS total_vuelos,
    SUM(CASE WHEN is_cancelled = 1 THEN 1 ELSE 0 END) AS vuelos_cancelados,
    SUM(CASE WHEN is_cancelled = 0 AND delay_min > 0 THEN 1 ELSE 0 END) AS vuelos_retrasados,
    CAST(SUM(ticket_price_usd) AS DECIMAL(18,2)) AS ingreso_total_usd,
    CAST(AVG(ticket_price_usd) AS DECIMAL(10,2)) AS ticket_promedio_usd,
    CAST(AVG(CAST(delay_min AS FLOAT)) AS DECIMAL(10,2)) AS retraso_promedio_min,
    CAST(AVG(CAST(duration_min AS FLOAT)) AS DECIMAL(10,2)) AS duracion_promedio_min
FROM hechos_vuelo;
GO

CREATE OR ALTER VIEW vw_powerbi_vuelos_por_mes AS
SELECT
    f.anio,
    f.mes,
    f.nombre_mes,
    COUNT(*) AS total_vuelos,
    CAST(SUM(h.ticket_price_usd) AS DECIMAL(18,2)) AS ingreso_total_usd,
    SUM(CASE WHEN h.is_cancelled = 1 THEN 1 ELSE 0 END) AS vuelos_cancelados,
    CAST(AVG(CAST(h.delay_min AS FLOAT)) AS DECIMAL(10,2)) AS retraso_promedio_min
FROM hechos_vuelo h
JOIN dim_fecha f
    ON f.id_fecha = h.id_fecha_salida
GROUP BY
    f.anio,
    f.mes,
    f.nombre_mes;
GO

CREATE OR ALTER VIEW vw_powerbi_aerolineas AS
SELECT
    a.codigo_aerolinea,
    a.nombre_aerolinea,
    COUNT(*) AS total_vuelos,
    CAST(SUM(h.ticket_price_usd) AS DECIMAL(18,2)) AS ingreso_total_usd,
    CAST(AVG(h.ticket_price_usd) AS DECIMAL(10,2)) AS ticket_promedio_usd,
    SUM(CASE WHEN h.is_cancelled = 1 THEN 1 ELSE 0 END) AS vuelos_cancelados,
    CAST(AVG(CAST(h.delay_min AS FLOAT)) AS DECIMAL(10,2)) AS retraso_promedio_min
FROM hechos_vuelo h
JOIN dim_aerolinea a
    ON a.id_aerolinea = h.id_aerolinea
GROUP BY
    a.codigo_aerolinea,
    a.nombre_aerolinea;
GO

CREATE OR ALTER VIEW vw_powerbi_destinos AS
SELECT
    ap.codigo_iata AS destino,
    COUNT(*) AS total_vuelos,
    CAST(SUM(h.ticket_price_usd) AS DECIMAL(18,2)) AS ingreso_total_usd,
    SUM(CASE WHEN h.is_cancelled = 1 THEN 1 ELSE 0 END) AS vuelos_cancelados,
    CAST(AVG(CAST(h.delay_min AS FLOAT)) AS DECIMAL(10,2)) AS retraso_promedio_min
FROM hechos_vuelo h
JOIN dim_aeropuerto ap
    ON ap.id_aeropuerto = h.id_aeropuerto_destino
GROUP BY
    ap.codigo_iata;
GO

CREATE OR ALTER VIEW vw_powerbi_canales_venta AS
SELECT
    c.canal,
    p.metodo_pago,
    cb.clase_cabina,
    COUNT(*) AS total_vuelos,
    CAST(SUM(h.ticket_price_usd) AS DECIMAL(18,2)) AS ingreso_total_usd,
    CAST(AVG(h.ticket_price_usd) AS DECIMAL(10,2)) AS ticket_promedio_usd
FROM hechos_vuelo h
JOIN dim_canal_venta c
    ON c.id_canal = h.id_canal
JOIN dim_pago p
    ON p.id_pago = h.id_pago
JOIN dim_cabina cb
    ON cb.id_cabina = h.id_cabina
GROUP BY
    c.canal,
    p.metodo_pago,
    cb.clase_cabina;
GO
