-- Cada fila compara dos totales calculados; no hay cifras esperadas fijas.
WITH comprobaciones AS (
    SELECT 'lineas_venta' AS check_name,
        (SELECT count(*) FROM raw.venta_detalle)::numeric AS expected,
        (SELECT count(*) FROM marts.fact_ventas)::numeric AS actual
    UNION ALL
    SELECT 'cortes_inventario',
        (SELECT count(*) FROM raw.inventario_bodega),
        (SELECT count(*) FROM marts.fact_inventario)
    UNION ALL
    SELECT 'devoluciones_preservadas',
        (SELECT count(*) FROM raw.devoluciones),
        (SELECT count(*) FROM marts.fact_devoluciones)
    UNION ALL
    SELECT 'metas_preservadas',
        (SELECT count(*) FROM raw.metas_ventas),
        (SELECT count(*) FROM marts.fact_metas)
    UNION ALL
    SELECT 'cotizaciones_preservadas',
        (SELECT count(*) FROM raw.proveedores_precios),
        (SELECT count(*) FROM marts.fact_proveedor_precio)
    UNION ALL
    SELECT 'ventas_completadas_importe',
        (SELECT coalesce(sum(d.subtotal),0) FROM staging.stg_venta_detalle d
         JOIN staging.stg_venta v USING (id_venta) WHERE v.estado='COMPLETADA'),
        (SELECT coalesce(sum(importe_neto_vendido),0) FROM marts.fact_ventas)
    UNION ALL
    SELECT 'ventas_reporte_sin_duplicacion',
        (SELECT coalesce(sum(importe_neto_vendido),0) FROM marts.fact_ventas),
        (SELECT coalesce(sum(ventas_completadas),0) FROM marts.rpt_ventas_mensuales)
    UNION ALL
    SELECT 'metas_reporte_sin_duplicacion',
        (SELECT sum(meta_ventas) FROM marts.fact_metas),
        (SELECT sum(meta_ventas) FROM marts.rpt_ventas_mensuales)
    UNION ALL
    SELECT 'devoluciones_reporte_sin_duplicacion',
        (SELECT sum(importe_devolucion_estimado) FROM marts.fact_devoluciones),
        (SELECT sum(devoluciones_estimadas) FROM marts.rpt_ventas_mensuales)
    UNION ALL
    SELECT 'ultimo_corte_completo',
        (SELECT count(*) FROM staging.stg_inventario_bodega
         WHERE fecha_corte=(SELECT max(fecha_corte) FROM staging.stg_inventario_bodega)),
        (SELECT count(*) FROM marts.rpt_inventario_actual)
    UNION ALL
    SELECT 'producto_dimension', (SELECT count(*) FROM raw.producto), (SELECT count(*) FROM marts.dim_producto)
)
SELECT check_name, expected, actual, abs(expected-actual) <= 0.01 AS passed
FROM comprobaciones ORDER BY check_name;
