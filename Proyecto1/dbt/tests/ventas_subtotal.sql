select * from {{ ref('stg_venta_detalle') }}
where cantidad is null or cantidad <= 0 or precio_unitario is null or precio_unitario < 0
or descuento is null or descuento not between 0 and 1
or subtotal is null or abs(subtotal - round(cantidad * precio_unitario * (1 - descuento), 2)) > 0.01
