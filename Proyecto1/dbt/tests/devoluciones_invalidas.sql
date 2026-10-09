{{ config(severity='warn', store_failures=true) }}
select * from {{ ref('int_devoluciones') }} where resultado_validacion != 'VALIDA'
