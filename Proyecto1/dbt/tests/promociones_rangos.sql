select * from {{ ref('stg_promociones') }}
where fecha_inicio is null or fecha_fin is null or fecha_fin < fecha_inicio
or porcentaje_descuento is null or porcentaje_descuento not between 0 and 1
