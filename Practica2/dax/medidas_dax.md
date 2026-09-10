# Medidas DAX para Dashboard VuelosDW


## Volumen de vuelos

```DAX
Total Vuelos =
COUNTROWS(hechos_vuelo)
```

```DAX
Vuelos Cancelados =
CALCULATE(
    [Total Vuelos],
    hechos_vuelo[status] = "CANCELLED"
)
```

```DAX
Vuelos No Cancelados =
CALCULATE(
    [Total Vuelos],
    hechos_vuelo[status] <> "CANCELLED"
)
```

```DAX
Tasa Cancelacion =
DIVIDE([Vuelos Cancelados], [Total Vuelos])
```

```DAX
Vuelos Retrasados =
CALCULATE(
    [Total Vuelos],
    hechos_vuelo[status] <> "CANCELLED",
    hechos_vuelo[delay_min] > 0
)
```

```DAX
Tasa Retraso =
DIVIDE([Vuelos Retrasados], [Vuelos No Cancelados])
```

## Ingresos

```DAX
Ingreso Total USD =
SUM(hechos_vuelo[ticket_price_usd])
```

```DAX
Ticket Promedio USD =
AVERAGE(hechos_vuelo[ticket_price_usd])
```

```DAX
Ingreso por Vuelo USD =
DIVIDE([Ingreso Total USD], [Total Vuelos])
```

```DAX
Ingreso Vuelos No Cancelados USD =
CALCULATE(
    [Ingreso Total USD],
    hechos_vuelo[status] <> "CANCELLED"
)
```

## Retrasos y duracion

```DAX
Retraso Promedio Min =
AVERAGE(hechos_vuelo[delay_min])
```

```DAX
Retraso Total Min =
SUM(hechos_vuelo[delay_min])
```

```DAX
Duracion Promedio Min =
AVERAGE(hechos_vuelo[duration_min])
```

```DAX
Puntualidad =
1 - [Tasa Retraso]
```

```DAX
Objetivo Puntualidad =
0.85
```

```DAX
Brecha Puntualidad =
[Puntualidad] - [Objetivo Puntualidad]
```

## Equipaje

```DAX
Bolsas Totales =
SUM(hechos_vuelo[bags_total])
```

```DAX
Bolsas Documentadas =
SUM(hechos_vuelo[bags_checked])
```

```DAX
Promedio Bolsas por Vuelo =
AVERAGE(hechos_vuelo[bags_total])
```

```DAX
Tasa Equipaje Documentado =
DIVIDE([Bolsas Documentadas], [Bolsas Totales])
```

## Pasajeros

```DAX
Pasajeros Unicos =
DISTINCTCOUNT(dim_pasajero[passenger_uuid])
```

```DAX
Edad Promedio =
AVERAGE(dim_pasajero[edad])
```

## Analisis por fecha de reserva

Usar esta medida cuando se quiera analizar los vuelos por la fecha en que fueron reservados y no por la fecha de salida.

```DAX
Total Vuelos por Fecha Reserva =
CALCULATE(
    [Total Vuelos],
    USERELATIONSHIP(dim_fecha[id_fecha], hechos_vuelo[id_fecha_reserva])
)
```

```DAX
Ingreso por Fecha Reserva USD =
CALCULATE(
    [Ingreso Total USD],
    USERELATIONSHIP(dim_fecha[id_fecha], hechos_vuelo[id_fecha_reserva])
)
```

## KPIs con objetivo

```DAX
Objetivo Tasa Cancelacion =
0.05
```

```DAX
Brecha Tasa Cancelacion =
[Tasa Cancelacion] - [Objetivo Tasa Cancelacion]
```

```DAX
Objetivo Retraso Promedio Min =
15
```

```DAX
Brecha Retraso Promedio Min =
[Retraso Promedio Min] - [Objetivo Retraso Promedio Min]
```

```DAX
Objetivo Ticket Promedio USD =
150
```

```DAX
Brecha Ticket Promedio USD =
[Ticket Promedio USD] - [Objetivo Ticket Promedio USD]
```

## Formato recomendado

| Medida | Formato |
|---|---|
| `Ingreso Total USD` | Moneda, 2 decimales |
| `Ticket Promedio USD` | Moneda, 2 decimales |
| `Ingreso por Vuelo USD` | Moneda, 2 decimales |
| `Tasa Cancelacion` | Porcentaje, 2 decimales |
| `Tasa Retraso` | Porcentaje, 2 decimales |
| `Puntualidad` | Porcentaje, 2 decimales |
| `Objetivo Puntualidad` | Porcentaje, 2 decimales |
| `Brecha Puntualidad` | Porcentaje, 2 decimales |
| `Retraso Promedio Min` | Numero decimal, 2 decimales |
| `Duracion Promedio Min` | Numero decimal, 2 decimales |
