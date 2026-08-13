USE VuelosDW;
GO

-- 1) Validacion de carga: total de registros en cada tabla
SELECT 'dim_fecha'        AS tabla, COUNT(*) AS filas FROM dim_fecha
UNION ALL SELECT 'dim_aerolinea',    COUNT(*) FROM dim_aerolinea
UNION ALL SELECT 'dim_aeropuerto',   COUNT(*) FROM dim_aeropuerto
UNION ALL SELECT 'dim_pasajero',     COUNT(*) FROM dim_pasajero
UNION ALL SELECT 'dim_canal_venta',  COUNT(*) FROM dim_canal_venta
UNION ALL SELECT 'dim_pago',         COUNT(*) FROM dim_pago
UNION ALL SELECT 'dim_cabina',       COUNT(*) FROM dim_cabina
UNION ALL SELECT 'hechos_vuelo',     COUNT(*) FROM hechos_vuelo;
GO

-- 2) Numero total de vuelos cargados
SELECT COUNT(*) AS total_vuelos FROM hechos_vuelo;
GO

-- 3) Top 5 destinos mas frecuentes
SELECT TOP 5
    ap.codigo_iata          AS destino,
    COUNT(*)                AS cantidad_vuelos
FROM hechos_vuelo h
JOIN dim_aeropuerto ap ON ap.id_aeropuerto = h.id_aeropuerto_destino
GROUP BY ap.codigo_iata
ORDER BY cantidad_vuelos DESC;
GO

-- 4) Top 5 aerolineas por numero de vuelos
SELECT TOP 5
    al.nombre_aerolinea,
    COUNT(*) AS cantidad_vuelos
FROM hechos_vuelo h
JOIN dim_aerolinea al ON al.id_aerolinea = h.id_aerolinea
GROUP BY al.nombre_aerolinea
ORDER BY cantidad_vuelos DESC;
GO

-- 5) Distribucion de pasajeros por genero
SELECT
    p.genero,
    COUNT(*)                                              AS cantidad,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS porcentaje
FROM hechos_vuelo h
JOIN dim_pasajero p ON p.id_pasajero = h.id_pasajero
GROUP BY p.genero
ORDER BY cantidad DESC;
GO

-- 6) Distribucion por canal de venta
SELECT
    c.canal,
    COUNT(*) AS cantidad_vuelos
FROM hechos_vuelo h
JOIN dim_canal_venta c ON c.id_canal = h.id_canal
GROUP BY c.canal
ORDER BY cantidad_vuelos DESC;
GO

-- 7) Porcentaje de vuelos cancelados / retrasados / a tiempo
SELECT
    status,
    COUNT(*)                                                      AS cantidad,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS porcentaje
FROM hechos_vuelo
GROUP BY status
ORDER BY cantidad DESC;
GO

-- 8) Ingreso total y ticket promedio por aerolinea
SELECT
    al.nombre_aerolinea,
    COUNT(*)                                   AS cantidad_vuelos,
    SUM(h.ticket_price_usd)                    AS ingreso_total_usd,
    CAST(AVG(h.ticket_price_usd) AS DECIMAL(10,2)) AS ticket_promedio_usd
FROM hechos_vuelo h
JOIN dim_aerolinea al ON al.id_aerolinea = h.id_aerolinea
GROUP BY al.nombre_aerolinea
ORDER BY ingreso_total_usd DESC;
GO

-- 9) Retraso promedio por aeropuerto de origen, solo vuelos no cancelados
SELECT TOP 10
    ap.codigo_iata                                  AS origen,
    COUNT(*)                                        AS vuelos,
    CAST(AVG(CAST(h.delay_min AS FLOAT)) AS DECIMAL(6,2)) AS retraso_promedio_min
FROM hechos_vuelo h
JOIN dim_aeropuerto ap ON ap.id_aeropuerto = h.id_aeropuerto_origen
WHERE h.is_cancelled = 0
GROUP BY ap.codigo_iata
ORDER BY retraso_promedio_min DESC;
GO

-- 10) Vuelos por mes
SELECT
    f.anio,
    f.mes,
    f.nombre_mes,
    COUNT(*) AS cantidad_vuelos
FROM hechos_vuelo h
JOIN dim_fecha f ON f.id_fecha = h.id_fecha_salida
GROUP BY f.anio, f.mes, f.nombre_mes
ORDER BY f.anio, f.mes;
GO
