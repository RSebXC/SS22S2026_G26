select distinct md5(canal) as canal_key, canal from {{ ref('stg_venta') }}
