select distinct md5(metodo_pago) as pago_key, metodo_pago from {{ ref('stg_venta') }}
