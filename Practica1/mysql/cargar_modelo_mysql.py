"""Crea VuelosDW en MySQL y carga el modelo dimensional de la P1."""

from pathlib import Path
from urllib.parse import quote_plus

import pandas as pd
from sqlalchemy import create_engine, text


BASE_DIR = Path(__file__).resolve().parents[1]
DATA_DIR = BASE_DIR / "data" / "powerbi"
PASSWORD = "Vuelos2026!"


def make_engine(password: str, database: str | None = None):
    target = f"/{database}" if database else "/"
    url = (
        "mysql+pymysql://root:"
        + quote_plus(password)
        + "@127.0.0.1:3306"
        + target
        + "?charset=utf8mb4"
    )
    return create_engine(url, pool_pre_ping=True)


def connect_root():
    # La primera ejecucion usa root sin password; las siguientes usan el password local.
    for password in ("", PASSWORD):
        try:
            engine = make_engine(password)
            with engine.connect():
                return engine, password
        except Exception:
            continue
    raise RuntimeError("No fue posible conectarse a MySQL como root.")


def main() -> None:
    try:
        import pymysql  # noqa: F401
    except ImportError as error:
        raise RuntimeError("Falta pymysql. Ejecuta: python -m pip install pymysql") from error

    root_engine, current_password = connect_root()
    with root_engine.begin() as connection:
        connection.execute(text("CREATE DATABASE IF NOT EXISTS VuelosDW CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"))
        if current_password != PASSWORD:
            connection.execute(text("ALTER USER 'root'@'localhost' IDENTIFIED BY :password"), {"password": PASSWORD})
    root_engine.dispose()

    engine = make_engine(PASSWORD, "VuelosDW")
    with engine.begin() as connection:
        connection.execute(text("SET FOREIGN_KEY_CHECKS = 0"))
        for table in (
            "hechos_vuelo", "dim_fecha", "dim_aerolinea", "dim_aeropuerto",
            "dim_pasajero", "dim_canal_venta", "dim_pago", "dim_cabina",
        ):
            connection.execute(text(f"DROP TABLE IF EXISTS {table}"))
        connection.execute(text("""
            CREATE TABLE dim_fecha (
                id_fecha INT NOT NULL PRIMARY KEY,
                fecha DATE NOT NULL,
                anio SMALLINT NOT NULL,
                mes TINYINT NOT NULL,
                nombre_mes VARCHAR(20) NOT NULL,
                dia TINYINT NOT NULL,
                trimestre TINYINT NOT NULL,
                dia_semana TINYINT NOT NULL,
                nombre_dia_semana VARCHAR(15) NOT NULL,
                es_fin_de_semana TINYINT NOT NULL
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_aerolinea (
                id_aerolinea INT NOT NULL PRIMARY KEY,
                codigo_aerolinea CHAR(2) NOT NULL UNIQUE,
                nombre_aerolinea VARCHAR(100) NOT NULL
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_aeropuerto (
                id_aeropuerto INT NOT NULL PRIMARY KEY,
                codigo_iata CHAR(3) NOT NULL UNIQUE
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_pasajero (
                id_pasajero INT NOT NULL PRIMARY KEY,
                passenger_uuid VARCHAR(36) NOT NULL UNIQUE,
                genero CHAR(1) NOT NULL,
                edad TINYINT NULL,
                nacionalidad CHAR(2) NULL
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_canal_venta (
                id_canal INT NOT NULL PRIMARY KEY,
                canal VARCHAR(30) NOT NULL UNIQUE
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_pago (
                id_pago INT NOT NULL PRIMARY KEY,
                metodo_pago VARCHAR(30) NOT NULL UNIQUE
            )
        """))
        connection.execute(text("""
            CREATE TABLE dim_cabina (
                id_cabina INT NOT NULL PRIMARY KEY,
                clase_cabina VARCHAR(30) NOT NULL UNIQUE
            )
        """))

    tables = (
        "dim_fecha", "dim_aerolinea", "dim_aeropuerto", "dim_pasajero",
        "dim_canal_venta", "dim_pago", "dim_cabina",
    )
    for table in tables:
        frame = pd.read_csv(DATA_DIR / f"{table}.csv", encoding="utf-8-sig")
        if table == "dim_fecha":
            frame["fecha"] = pd.to_datetime(frame["fecha"]).dt.date
        frame.to_sql(table, engine, if_exists="append", index=False, chunksize=1000, method="multi")

    fact = pd.read_csv(DATA_DIR / "hechos_vuelo.csv", encoding="utf-8-sig")
    fact.to_sql("hechos_vuelo", engine, if_exists="replace", index=False, chunksize=1000, method="multi")

    with engine.begin() as connection:
        connection.execute(text("""
            ALTER TABLE hechos_vuelo
                MODIFY id_hecho BIGINT NOT NULL PRIMARY KEY,
                MODIFY id_fecha_salida INT NOT NULL,
                MODIFY id_fecha_reserva INT NOT NULL,
                MODIFY id_aerolinea INT NOT NULL,
                MODIFY id_aeropuerto_origen INT NOT NULL,
                MODIFY id_aeropuerto_destino INT NOT NULL,
                MODIFY id_pasajero INT NOT NULL,
                MODIFY id_canal INT NOT NULL,
                MODIFY id_pago INT NOT NULL,
                MODIFY id_cabina INT NOT NULL,
                MODIFY is_cancelled TINYINT NOT NULL,
                MODIFY ticket_price_usd DECIMAL(10, 2) NOT NULL,
                MODIFY bags_total TINYINT NOT NULL,
                MODIFY bags_checked TINYINT NOT NULL
        """))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_fecha_salida FOREIGN KEY (id_fecha_salida) REFERENCES dim_fecha(id_fecha)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_fecha_reserva FOREIGN KEY (id_fecha_reserva) REFERENCES dim_fecha(id_fecha)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_aerolinea FOREIGN KEY (id_aerolinea) REFERENCES dim_aerolinea(id_aerolinea)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_origen FOREIGN KEY (id_aeropuerto_origen) REFERENCES dim_aeropuerto(id_aeropuerto)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_destino FOREIGN KEY (id_aeropuerto_destino) REFERENCES dim_aeropuerto(id_aeropuerto)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_pasajero FOREIGN KEY (id_pasajero) REFERENCES dim_pasajero(id_pasajero)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_canal FOREIGN KEY (id_canal) REFERENCES dim_canal_venta(id_canal)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_pago FOREIGN KEY (id_pago) REFERENCES dim_pago(id_pago)"))
        connection.execute(text("ALTER TABLE hechos_vuelo ADD CONSTRAINT fk_h_cabina FOREIGN KEY (id_cabina) REFERENCES dim_cabina(id_cabina)"))

    print("Base VuelosDW creada en MySQL.")
    for table in (*tables, "hechos_vuelo"):
        with engine.connect() as connection:
            total = connection.execute(text(f"SELECT COUNT(*) FROM {table}"))
            print(f"{table}: {total.scalar_one():,} filas")
    print("Usuario: root | Password local: Vuelos2026! | Puerto: 3306")


if __name__ == "__main__":
    main()
