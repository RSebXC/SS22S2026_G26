-- 1. Evolución mensual de ventas, devoluciones estimadas y metas.
SELECT periodo, sum(ventas_completadas) AS ventas,
       sum(devoluciones_estimadas) AS devoluciones_estimadas,
       sum(ventas_ajustadas_estimadas) AS ventas_ajustadas_estimadas,
       sum(meta_ventas) AS meta, sum(ventas_completadas)/nullif(sum(meta_ventas),0) AS cumplimiento
FROM marts.rpt_ventas_mensuales GROUP BY periodo ORDER BY periodo;

-- 2. Ventas y margen de referencia por categoría.
SELECT p.categoria, sum(v.importe_neto_vendido) AS ventas,
       sum(v.unidades_vendidas) AS unidades, sum(v.margen_estimado) AS margen_estimado
FROM marts.fact_ventas v JOIN marts.dim_producto p USING (producto_key)
GROUP BY p.categoria ORDER BY ventas DESC;

-- 3. Sucursales por ventas y cumplimiento de meta.
SELECT sucursal, sum(ventas_completadas) AS ventas, sum(meta_ventas) AS meta,
       sum(ventas_completadas)/nullif(sum(meta_ventas),0) AS cumplimiento
FROM marts.rpt_ventas_mensuales GROUP BY sucursal ORDER BY ventas DESC;

-- 4. Canales y segmentos de cliente.
SELECT c.canal, cl.tipo_cliente, sum(v.importe_neto_vendido) AS ventas,
       count(DISTINCT v.id_venta) FILTER (WHERE v.estado='COMPLETADA') AS tickets
FROM marts.fact_ventas v JOIN marts.dim_canal c USING (canal_key)
JOIN marts.dim_cliente cl USING (cliente_key)
GROUP BY c.canal,cl.tipo_cliente ORDER BY ventas DESC;

-- 5. Inventario al último corte disponible; no sumar existencias entre meses.
SELECT sucursal, max(fecha_corte) AS corte, sum(stock_disponible) AS existencias,
       count(*) FILTER (WHERE sin_stock) AS productos_sin_stock,
       count(*) FILTER (WHERE bajo_minimo) AS productos_bajo_minimo,
       count(*) FILTER (WHERE vence_en_30_dias) AS lotes_por_vencer,
       sum(valor_inventario_referencia) AS valor_referencia
FROM marts.rpt_inventario_actual GROUP BY sucursal ORDER BY productos_bajo_minimo DESC;

-- 6. Menor costo cotizado vigente al último corte, por producto.
WITH corte AS (SELECT max(fecha) AS fecha FROM marts.dim_fecha f
    JOIN marts.fact_inventario i USING (fecha_key)),
vigentes AS (
    SELECT c.*, row_number() OVER (PARTITION BY proveedor_key,producto_key ORDER BY fecha_vigencia DESC) AS rn
    FROM marts.fact_proveedor_precio c, corte WHERE c.fecha_vigencia <= corte.fecha
)
SELECT p.nombre AS producto, pr.proveedor, v.costo_proveedor, v.plazo_dias, v.fecha_vigencia
FROM vigentes v JOIN marts.dim_producto p USING (producto_key)
JOIN marts.dim_proveedor pr USING (proveedor_key)
WHERE rn=1 ORDER BY p.nombre,v.costo_proveedor;

-- 7. Devoluciones por motivo y calidad de su relación con la venta original.
SELECT motivo, resultado_validacion, count(*) AS registros, sum(cantidad) AS unidades,
       sum(importe_devolucion_estimado) AS importe_estimado
FROM marts.fact_devoluciones GROUP BY motivo,resultado_validacion ORDER BY registros DESC;

-- 8. Ventas potencialmente elegibles para promociones, sin duplicar líneas.
SELECT count(*) AS lineas_elegibles, sum(v.importe_neto_vendido) AS ventas_elegibles
FROM marts.fact_ventas v WHERE EXISTS (
    SELECT 1 FROM marts.bridge_promocion_venta b WHERE b.venta_key=v.venta_key
);
