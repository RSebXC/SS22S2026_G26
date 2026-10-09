select * from {{ ref('stg_cliente') }} where id_cliente is null
