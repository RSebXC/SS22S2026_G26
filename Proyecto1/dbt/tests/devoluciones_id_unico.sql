select id_devolucion from {{ ref('stg_devoluciones') }}
group by id_devolucion having id_devolucion is null or count(*) != 1
