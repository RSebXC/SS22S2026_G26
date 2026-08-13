IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'VuelosDW')
BEGIN
    CREATE DATABASE VuelosDW;
END
GO

USE VuelosDW;
GO

-- DIMENSIONES

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_fecha')
BEGIN
    CREATE TABLE dim_fecha (
        id_fecha            INT             NOT NULL PRIMARY KEY,  -- formato YYYYMMDD
        fecha               DATE            NOT NULL,
        anio                SMALLINT        NOT NULL,
        mes                 TINYINT         NOT NULL,
        nombre_mes          VARCHAR(20)     NOT NULL,
        dia                 TINYINT         NOT NULL,
        trimestre           TINYINT         NOT NULL,
        dia_semana          TINYINT         NOT NULL,   -- 1=Lunes ... 7=Domingo
        nombre_dia_semana   VARCHAR(15)     NOT NULL,
        es_fin_de_semana    BIT             NOT NULL
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_aerolinea')
BEGIN
    CREATE TABLE dim_aerolinea (
        id_aerolinea        INT IDENTITY(1,1) PRIMARY KEY,
        codigo_aerolinea    CHAR(2)         NOT NULL,
        nombre_aerolinea    VARCHAR(100)    NOT NULL,
        CONSTRAINT UQ_dim_aerolinea UNIQUE (codigo_aerolinea)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_aeropuerto')
BEGIN
    CREATE TABLE dim_aeropuerto (
        id_aeropuerto       INT IDENTITY(1,1) PRIMARY KEY,
        codigo_iata         CHAR(3)         NOT NULL,
        CONSTRAINT UQ_dim_aeropuerto UNIQUE (codigo_iata)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_pasajero')
BEGIN
    CREATE TABLE dim_pasajero (
        id_pasajero         INT IDENTITY(1,1) PRIMARY KEY,
        passenger_uuid      VARCHAR(36)     NOT NULL,
        genero              CHAR(1)         NOT NULL,   -- M / F / X
        edad                TINYINT         NULL,
        nacionalidad        CHAR(2)         NULL,
        CONSTRAINT UQ_dim_pasajero UNIQUE (passenger_uuid)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_canal_venta')
BEGIN
    CREATE TABLE dim_canal_venta (
        id_canal            INT IDENTITY(1,1) PRIMARY KEY,
        canal               VARCHAR(30)     NOT NULL,
        CONSTRAINT UQ_dim_canal_venta UNIQUE (canal)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_pago')
BEGIN
    CREATE TABLE dim_pago (
        id_pago             INT IDENTITY(1,1) PRIMARY KEY,
        metodo_pago         VARCHAR(30)     NOT NULL,
        CONSTRAINT UQ_dim_pago UNIQUE (metodo_pago)
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'dim_cabina')
BEGIN
    CREATE TABLE dim_cabina (
        id_cabina           INT IDENTITY(1,1) PRIMARY KEY,
        clase_cabina        VARCHAR(30)     NOT NULL,
        CONSTRAINT UQ_dim_cabina UNIQUE (clase_cabina)
    );
END
GO


-- TABLA DE HECHOS


IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'hechos_vuelo')
BEGIN
    CREATE TABLE hechos_vuelo (
        id_hecho                BIGINT IDENTITY(1,1) PRIMARY KEY,

        record_id               INT             NOT NULL,
        flight_number            VARCHAR(10)     NOT NULL,
        seat                     VARCHAR(5)      NULL,

        -- Llaves foraneas a dimensiones
        id_fecha_salida          INT             NOT NULL REFERENCES dim_fecha(id_fecha),
        id_fecha_reserva         INT             NOT NULL REFERENCES dim_fecha(id_fecha),
        id_aerolinea             INT             NOT NULL REFERENCES dim_aerolinea(id_aerolinea),
        id_aeropuerto_origen     INT             NOT NULL REFERENCES dim_aeropuerto(id_aeropuerto),
        id_aeropuerto_destino    INT             NOT NULL REFERENCES dim_aeropuerto(id_aeropuerto),
        id_pasajero              INT             NOT NULL REFERENCES dim_pasajero(id_pasajero),
        id_canal                 INT             NOT NULL REFERENCES dim_canal_venta(id_canal),
        id_pago                  INT             NOT NULL REFERENCES dim_pago(id_pago),
        id_cabina                INT             NOT NULL REFERENCES dim_cabina(id_cabina),

        -- Atributo de contexto
        status                    VARCHAR(20)     NOT NULL,
        is_cancelled              BIT             NOT NULL,

        -- Medidas
        duration_min              SMALLINT        NULL,
        delay_min                 SMALLINT        NULL,
        ticket_price_usd          DECIMAL(10,2)   NOT NULL,
        bags_total                TINYINT         NOT NULL,
        bags_checked               TINYINT         NOT NULL
    );
END
GO


-- INDICES para acelerar las consultas analiticas (agrupaciones por FK)


IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_hechos_vuelo_aerolinea')
    CREATE INDEX IX_hechos_vuelo_aerolinea ON hechos_vuelo(id_aerolinea);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_hechos_vuelo_destino')
    CREATE INDEX IX_hechos_vuelo_destino ON hechos_vuelo(id_aeropuerto_destino);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_hechos_vuelo_fecha_salida')
    CREATE INDEX IX_hechos_vuelo_fecha_salida ON hechos_vuelo(id_fecha_salida);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_hechos_vuelo_pasajero')
    CREATE INDEX IX_hechos_vuelo_pasajero ON hechos_vuelo(id_pasajero);
GO
