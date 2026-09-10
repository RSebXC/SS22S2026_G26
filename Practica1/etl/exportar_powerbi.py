"""Exporta el modelo dimensional de la P1 a CSV para cargarlo en Power BI.

Esta ruta no necesita SQL Server: conserva las mismas tablas, llaves y
columnas del modelo estrella que produce el notebook principal.
"""

from pathlib import Path

import pandas as pd


BASE_DIR = Path(__file__).resolve().parents[1]
INPUT_PATH = BASE_DIR / "data" / "dataset_vuelos_crudo.csv"
OUTPUT_DIR = BASE_DIR / "data" / "powerbi"

MESES_ES = [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre",
]
DIAS_ES = [
    "Lunes", "Martes", "Miercoles", "Jueves", "Viernes", "Sabado", "Domingo",
]


def parse_mixed_datetime(series: pd.Series) -> pd.Series:
    """Acepta los dos formatos de fecha presentes en el CSV original."""
    values = series.astype("string").str.strip()
    parsed = pd.to_datetime(values, format="%d/%m/%Y %H:%M", errors="coerce")
    missing = parsed.isna() & values.notna()
    fallback = pd.to_datetime(
        values[missing], format="%m-%d-%Y %I:%M %p", errors="coerce"
    )
    parsed.loc[missing] = fallback
    return parsed


def build_date_dimension(*date_series: pd.Series) -> pd.DataFrame:
    dates = pd.concat(date_series).dropna().dt.normalize().unique()
    dimension = pd.DataFrame({"fecha": pd.to_datetime(dates)})
    dimension["id_fecha"] = dimension["fecha"].dt.strftime("%Y%m%d").astype(int)
    dimension["anio"] = dimension["fecha"].dt.year
    dimension["mes"] = dimension["fecha"].dt.month
    dimension["nombre_mes"] = dimension["mes"].map(lambda month: MESES_ES[month - 1])
    dimension["dia"] = dimension["fecha"].dt.day
    dimension["trimestre"] = dimension["fecha"].dt.quarter
    dimension["dia_semana"] = dimension["fecha"].dt.weekday + 1
    dimension["nombre_dia_semana"] = dimension["fecha"].dt.weekday.map(
        lambda day: DIAS_ES[day]
    )
    dimension["es_fin_de_semana"] = dimension["dia_semana"].isin([6, 7]).astype(int)
    dimension["fecha"] = dimension["fecha"].dt.strftime("%Y-%m-%d")
    columns = [
        "id_fecha", "fecha", "anio", "mes", "nombre_mes", "dia",
        "trimestre", "dia_semana", "nombre_dia_semana", "es_fin_de_semana",
    ]
    return dimension[columns].sort_values("id_fecha").reset_index(drop=True)


def normalize_gender(value: object) -> str:
    text = str(value).strip().lower()
    if text in ("m", "masculino"):
        return "M"
    if text in ("f", "femenino"):
        return "F"
    return "X"


def main() -> None:
    raw = pd.read_csv(INPUT_PATH)
    df = raw.copy()

    df["departure_dt"] = parse_mixed_datetime(df["departure_datetime"])
    df["arrival_dt"] = parse_mixed_datetime(df["arrival_datetime"])
    df["booking_dt"] = parse_mixed_datetime(df["booking_datetime"])

    for column in ("origin_airport", "destination_airport", "airline_code"):
        df[column] = df[column].astype("string").str.strip().str.upper()
    df["airline_name"] = df["airline_name"].astype("string").str.strip().str.title()
    for column in ("sales_channel", "payment_method", "cabin_class"):
        df[column] = (
            df[column].astype("string").str.strip().str.upper().fillna("DESCONOCIDO")
        )
    df["status"] = df["status"].astype("string").str.strip().str.upper()
    df["passenger_nationality"] = (
        df["passenger_nationality"].astype("string").str.strip().str.upper()
    )
    df["genero"] = df["passenger_gender"].map(normalize_gender)

    if df["departure_dt"].isna().any() or df["booking_dt"].isna().any():
        raise ValueError("Hay fechas de salida o reserva que no se pudieron interpretar.")

    dim_fecha = build_date_dimension(df["departure_dt"], df["booking_dt"])
    df["id_fecha_salida"] = df["departure_dt"].dt.strftime("%Y%m%d").astype(int)
    df["id_fecha_reserva"] = df["booking_dt"].dt.strftime("%Y%m%d").astype(int)

    dim_aerolinea = (
        df[["airline_code", "airline_name"]]
        .drop_duplicates("airline_code")
        .rename(columns={
            "airline_code": "codigo_aerolinea",
            "airline_name": "nombre_aerolinea",
        })
        .sort_values("codigo_aerolinea")
        .reset_index(drop=True)
    )
    dim_aerolinea.insert(0, "id_aerolinea", dim_aerolinea.index + 1)

    airports = sorted(
        pd.concat([df["origin_airport"], df["destination_airport"]])
        .dropna()
        .unique()
    )
    dim_aeropuerto = pd.DataFrame({"codigo_iata": airports})
    dim_aeropuerto.insert(0, "id_aeropuerto", dim_aeropuerto.index + 1)

    dim_pasajero = (
        df[["passenger_id", "genero", "passenger_age", "passenger_nationality"]]
        .drop_duplicates("passenger_id")
        .rename(columns={
            "passenger_id": "passenger_uuid",
            "passenger_age": "edad",
            "passenger_nationality": "nacionalidad",
        })
        .reset_index(drop=True)
    )
    dim_pasajero.insert(0, "id_pasajero", dim_pasajero.index + 1)

    def one_column_dimension(source: str, target: str, key: str) -> pd.DataFrame:
        values = pd.DataFrame({target: sorted(df[source].dropna().unique())})
        values.insert(0, key, values.index + 1)
        return values

    dim_canal_venta = one_column_dimension("sales_channel", "canal", "id_canal")
    dim_pago = one_column_dimension("payment_method", "metodo_pago", "id_pago")
    dim_cabina = one_column_dimension("cabin_class", "clase_cabina", "id_cabina")

    fact = df.merge(
        dim_aerolinea, left_on="airline_code", right_on="codigo_aerolinea", how="left"
    )
    fact = fact.merge(
        dim_aeropuerto.rename(columns={
            "id_aeropuerto": "id_aeropuerto_origen",
            "codigo_iata": "origin_airport",
        }),
        on="origin_airport", how="left",
    )
    fact = fact.merge(
        dim_aeropuerto.rename(columns={
            "id_aeropuerto": "id_aeropuerto_destino",
            "codigo_iata": "destination_airport",
        }),
        on="destination_airport", how="left",
    )
    fact = fact.merge(
        dim_pasajero[["id_pasajero", "passenger_uuid"]],
        left_on="passenger_id", right_on="passenger_uuid", how="left",
    )
    fact = fact.merge(
        dim_canal_venta.rename(columns={"canal": "sales_channel"}),
        on="sales_channel", how="left",
    )
    fact = fact.merge(
        dim_pago.rename(columns={"metodo_pago": "payment_method"}),
        on="payment_method", how="left",
    )
    fact = fact.merge(
        dim_cabina.rename(columns={"clase_cabina": "cabin_class"}),
        on="cabin_class", how="left",
    )

    hechos_vuelo = pd.DataFrame({
        "id_hecho": range(1, len(fact) + 1),
        "record_id": fact["record_id"].astype(int),
        "flight_number": fact["flight_number"],
        "seat": fact["seat"],
        "id_fecha_salida": fact["id_fecha_salida"],
        "id_fecha_reserva": fact["id_fecha_reserva"],
        "id_aerolinea": fact["id_aerolinea"],
        "id_aeropuerto_origen": fact["id_aeropuerto_origen"],
        "id_aeropuerto_destino": fact["id_aeropuerto_destino"],
        "id_pasajero": fact["id_pasajero"],
        "id_canal": fact["id_canal"],
        "id_pago": fact["id_pago"],
        "id_cabina": fact["id_cabina"],
        "status": fact["status"],
        "is_cancelled": (fact["status"] == "CANCELLED").astype(int),
        "duration_min": pd.to_numeric(fact["duration_min"], errors="coerce"),
        "delay_min": pd.to_numeric(fact["delay_min"], errors="coerce"),
        "ticket_price_usd": pd.to_numeric(fact["ticket_price_usd_est"], errors="coerce"),
        "bags_total": pd.to_numeric(fact["bags_total"], errors="coerce").fillna(0),
        "bags_checked": pd.to_numeric(fact["bags_checked"], errors="coerce").fillna(0),
    })

    dimensions = {
        "dim_fecha": dim_fecha,
        "dim_aerolinea": dim_aerolinea,
        "dim_aeropuerto": dim_aeropuerto,
        "dim_pasajero": dim_pasajero,
        "dim_canal_venta": dim_canal_venta,
        "dim_pago": dim_pago,
        "dim_cabina": dim_cabina,
        "hechos_vuelo": hechos_vuelo,
    }
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, table in dimensions.items():
        table.to_csv(OUTPUT_DIR / f"{name}.csv", index=False, encoding="utf-8-sig")
        print(f"{name}: {len(table):,} filas")
    print(f"Archivos creados en: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
