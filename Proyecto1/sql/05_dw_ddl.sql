--
-- PostgreSQL database dump
--

\restrict izJF0dSbho7COmVn05DJIYY7AsjmYodNEh7lGiV2DdyKp3zsYbBa2AschYgEWZp

-- Dumped from database version 16.10 (Debian 16.10-1.pgdg13+1)
-- Dumped by pg_dump version 16.10 (Debian 16.10-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: audit; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA audit;


--
-- Name: intermediate; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA intermediate;


--
-- Name: marts; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA marts;


--
-- Name: raw; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA raw;


--
-- Name: staging; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA staging;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: load_runs; Type: TABLE; Schema: audit; Owner: -
--

CREATE TABLE audit.load_runs (
    batch_id uuid NOT NULL,
    started_at timestamp with time zone NOT NULL,
    completed_at timestamp with time zone DEFAULT now() NOT NULL,
    counts jsonb NOT NULL,
    file_hashes jsonb NOT NULL
);


--
-- Name: producto; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.producto (
    id_producto text,
    sku text,
    nombre text,
    id_categoria text,
    id_marca text,
    unidad_medida text,
    costo_base text,
    precio_lista text,
    activo text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: venta; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.venta (
    id_venta text,
    fecha text,
    id_cliente text,
    id_sucursal text,
    canal text,
    metodo_pago text,
    estado text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: venta_detalle; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.venta_detalle (
    id_detalle text,
    id_venta text,
    id_producto text,
    cantidad text,
    precio_unitario text,
    descuento text,
    subtotal text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: stg_producto; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_producto AS
 SELECT (NULLIF(TRIM(BOTH FROM id_producto), ''::text))::integer AS id_producto,
    NULLIF(TRIM(BOTH FROM sku), ''::text) AS sku,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    (NULLIF(TRIM(BOTH FROM id_categoria), ''::text))::integer AS id_categoria,
    (NULLIF(TRIM(BOTH FROM id_marca), ''::text))::integer AS id_marca,
    NULLIF(TRIM(BOTH FROM unidad_medida), ''::text) AS unidad_medida,
    (NULLIF(TRIM(BOTH FROM costo_base), ''::text))::numeric(12,2) AS costo_base,
    (NULLIF(TRIM(BOTH FROM precio_lista), ''::text))::numeric(12,2) AS precio_lista,
    (NULLIF(TRIM(BOTH FROM activo), ''::text))::boolean AS activo,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.producto;


--
-- Name: stg_venta; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_venta AS
 SELECT (NULLIF(TRIM(BOTH FROM id_venta), ''::text))::bigint AS id_venta,
    (NULLIF(TRIM(BOTH FROM fecha), ''::text))::date AS fecha,
    (NULLIF(TRIM(BOTH FROM id_cliente), ''::text))::integer AS id_cliente,
    (NULLIF(TRIM(BOTH FROM id_sucursal), ''::text))::integer AS id_sucursal,
    NULLIF(TRIM(BOTH FROM canal), ''::text) AS canal,
    NULLIF(TRIM(BOTH FROM metodo_pago), ''::text) AS metodo_pago,
    NULLIF(TRIM(BOTH FROM estado), ''::text) AS estado,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.venta;


--
-- Name: stg_venta_detalle; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_venta_detalle AS
 SELECT (NULLIF(TRIM(BOTH FROM id_detalle), ''::text))::bigint AS id_detalle,
    (NULLIF(TRIM(BOTH FROM id_venta), ''::text))::bigint AS id_venta,
    (NULLIF(TRIM(BOTH FROM id_producto), ''::text))::integer AS id_producto,
    (NULLIF(TRIM(BOTH FROM cantidad), ''::text))::integer AS cantidad,
    (NULLIF(TRIM(BOTH FROM precio_unitario), ''::text))::numeric(12,2) AS precio_unitario,
    (NULLIF(TRIM(BOTH FROM descuento), ''::text))::numeric(5,4) AS descuento,
    (NULLIF(TRIM(BOTH FROM subtotal), ''::text))::numeric(14,2) AS subtotal,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.venta_detalle;


--
-- Name: int_ventas; Type: VIEW; Schema: intermediate; Owner: -
--

CREATE VIEW intermediate.int_ventas AS
 SELECT d.id_detalle,
    d.id_venta,
    d.id_producto,
    v.id_cliente,
    v.id_sucursal,
    v.fecha,
    v.canal,
    v.metodo_pago,
    v.estado,
    d.cantidad,
    d.precio_unitario,
    d.descuento,
    d.subtotal,
    round(((d.cantidad)::numeric * d.precio_unitario), 2) AS importe_bruto,
    round((((d.cantidad)::numeric * d.precio_unitario) * d.descuento), 2) AS importe_descuento,
    round(((d.cantidad)::numeric * p.costo_base), 2) AS costo_referencia,
    p.id_categoria,
        CASE
            WHEN (v.estado = 'COMPLETADA'::text) THEN d.subtotal
            ELSE (0)::numeric
        END AS importe_neto_vendido,
        CASE
            WHEN (v.estado = 'COMPLETADA'::text) THEN d.cantidad
            ELSE 0
        END AS unidades_vendidas
   FROM ((staging.stg_venta_detalle d
     JOIN staging.stg_venta v USING (id_venta))
     JOIN staging.stg_producto p USING (id_producto));


--
-- Name: devoluciones; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.devoluciones (
    id_devolucion text,
    fecha text,
    id_venta text,
    id_producto text,
    cantidad text,
    motivo text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: stg_devoluciones; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_devoluciones AS
 SELECT (NULLIF(TRIM(BOTH FROM id_devolucion), ''::text))::bigint AS id_devolucion,
    (NULLIF(TRIM(BOTH FROM fecha), ''::text))::date AS fecha,
    (NULLIF(TRIM(BOTH FROM id_venta), ''::text))::bigint AS id_venta,
    (NULLIF(TRIM(BOTH FROM id_producto), ''::text))::integer AS id_producto,
    (NULLIF(TRIM(BOTH FROM cantidad), ''::text))::integer AS cantidad,
    NULLIF(TRIM(BOTH FROM motivo), ''::text) AS motivo,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.devoluciones;


--
-- Name: int_devoluciones; Type: VIEW; Schema: intermediate; Owner: -
--

CREATE VIEW intermediate.int_devoluciones AS
 WITH devoluciones AS (
         SELECT stg_devoluciones.id_devolucion,
            stg_devoluciones.fecha,
            stg_devoluciones.id_venta,
            stg_devoluciones.id_producto,
            stg_devoluciones.cantidad,
            stg_devoluciones.motivo,
            stg_devoluciones._loaded_at,
            stg_devoluciones._source,
            stg_devoluciones._batch_id,
            stg_devoluciones._source_row,
            sum(stg_devoluciones.cantidad) OVER (PARTITION BY stg_devoluciones.id_venta, stg_devoluciones.id_producto) AS cantidad_total_devuelta
           FROM staging.stg_devoluciones
        )
 SELECT d.id_devolucion,
    d.fecha,
    d.id_venta,
    d.id_producto,
    d.cantidad,
    d.motivo,
    d._loaded_at,
    d._source,
    d._batch_id,
    d._source_row,
    d.cantidad_total_devuelta,
    v.id_detalle,
    v.id_cliente,
    v.id_sucursal,
    v.cantidad AS cantidad_vendida,
    v.fecha AS fecha_venta,
    v.estado,
        CASE
            WHEN (v.id_detalle IS NULL) THEN 'SIN_LINEA_ORIGEN'::text
            WHEN (v.estado <> 'COMPLETADA'::text) THEN 'VENTA_NO_COMPLETADA'::text
            WHEN (d.fecha < v.fecha) THEN 'FECHA_ANTERIOR_A_VENTA'::text
            WHEN (d.cantidad <= 0) THEN 'CANTIDAD_NO_POSITIVA'::text
            WHEN (d.cantidad_total_devuelta > v.cantidad) THEN 'CANTIDAD_SUPERIOR_A_VENTA'::text
            ELSE 'VALIDA'::text
        END AS resultado_validacion,
    round((((d.cantidad)::numeric * v.subtotal) / (NULLIF(v.cantidad, 0))::numeric), 2) AS importe_estimado
   FROM (devoluciones d
     LEFT JOIN intermediate.int_ventas v USING (id_venta, id_producto));


--
-- Name: bridge_promocion_venta; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.bridge_promocion_venta (
    venta_key bigint NOT NULL,
    promocion_key integer NOT NULL
);


--
-- Name: dim_canal; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_canal (
    canal_key text NOT NULL,
    canal text
);


--
-- Name: dim_cliente; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_cliente (
    cliente_key integer NOT NULL,
    id_cliente integer,
    nit text,
    nombre text,
    tipo_cliente text,
    municipio text,
    departamento text,
    fecha_alta date
);


--
-- Name: dim_fecha; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_fecha (
    fecha_key integer NOT NULL,
    fecha date,
    anio integer,
    trimestre integer,
    mes integer,
    periodo text,
    dia integer,
    dia_semana integer,
    nombre_mes text
);


--
-- Name: dim_pago; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_pago (
    pago_key text NOT NULL,
    metodo_pago text
);


--
-- Name: dim_producto; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_producto (
    producto_key integer NOT NULL,
    id_producto integer,
    sku text,
    nombre text,
    id_categoria integer,
    id_marca integer,
    unidad_medida text,
    costo_base numeric(12,2),
    precio_lista numeric(12,2),
    activo boolean,
    categoria text,
    marca text
);


--
-- Name: dim_promocion; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_promocion (
    promocion_key integer NOT NULL,
    id_promocion integer,
    nombre text,
    fecha_inicio date,
    fecha_fin date,
    id_categoria integer,
    categoria text,
    porcentaje_descuento numeric(5,4)
);


--
-- Name: dim_proveedor; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_proveedor (
    proveedor_key integer NOT NULL,
    id_proveedor integer,
    proveedor text
);


--
-- Name: dim_sucursal; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.dim_sucursal (
    sucursal_key integer NOT NULL,
    id_sucursal integer,
    nombre text,
    ciudad text,
    departamento text
);


--
-- Name: fact_devoluciones; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.fact_devoluciones (
    devolucion_key bigint NOT NULL,
    id_devolucion bigint,
    id_venta bigint,
    id_detalle bigint,
    fecha_key integer,
    producto_key integer,
    cliente_key integer,
    sucursal_key integer,
    cantidad integer,
    motivo text,
    resultado_validacion text,
    es_valida boolean,
    importe_devolucion_estimado numeric,
    unidades_devueltas_validas integer
);


--
-- Name: fact_inventario; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.fact_inventario (
    inventario_key text NOT NULL,
    fecha_key integer,
    vencimiento_fecha_key integer,
    sucursal_key integer,
    producto_key integer,
    lote text,
    stock_disponible integer,
    stock_minimo integer,
    stock_maximo integer,
    fecha_vencimiento date,
    valor_inventario_referencia numeric,
    sin_stock boolean,
    bajo_minimo boolean,
    sobre_maximo boolean,
    dias_para_vencer integer,
    vencido boolean,
    vence_en_30_dias boolean,
    CONSTRAINT fact_inventario_range_check CHECK (((stock_disponible >= 0) AND (stock_minimo >= 0) AND (stock_maximo >= stock_minimo)))
);


--
-- Name: fact_metas; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.fact_metas (
    meta_key text NOT NULL,
    fecha_key integer,
    sucursal_key integer,
    periodo text,
    meta_ventas numeric(14,2),
    meta_unidades integer,
    CONSTRAINT fact_metas_range_check CHECK (((meta_ventas > (0)::numeric) AND (meta_unidades > 0)))
);


--
-- Name: fact_proveedor_precio; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.fact_proveedor_precio (
    precio_key text NOT NULL,
    proveedor_key integer,
    producto_key integer,
    fecha_key integer,
    costo_proveedor numeric(12,2),
    plazo_dias integer,
    fecha_vigencia date,
    CONSTRAINT fact_proveedor_precio_range_check CHECK (((costo_proveedor >= (0)::numeric) AND (plazo_dias > 0)))
);


--
-- Name: fact_ventas; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.fact_ventas (
    venta_key bigint NOT NULL,
    id_detalle bigint,
    id_venta bigint,
    fecha_key integer,
    producto_key integer,
    cliente_key integer,
    sucursal_key integer,
    canal_key text,
    pago_key text,
    estado text,
    cantidad integer,
    precio_unitario numeric(12,2),
    descuento numeric(5,4),
    importe_bruto numeric,
    importe_descuento numeric,
    importe_neto_linea numeric(14,2),
    importe_neto_vendido numeric,
    unidades_vendidas integer,
    costo_referencia numeric,
    costo_estimado_vendido numeric,
    margen_estimado numeric,
    CONSTRAINT fact_ventas_range_check CHECK (((cantidad > 0) AND (precio_unitario >= (0)::numeric) AND ((descuento >= (0)::numeric) AND (descuento <= (1)::numeric))))
);


--
-- Name: rpt_calidad_devoluciones; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.rpt_calidad_devoluciones (
    resultado_validacion text,
    registros bigint,
    unidades bigint
);


--
-- Name: rpt_inventario_actual; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.rpt_inventario_actual (
    inventario_key text,
    fecha_key integer,
    vencimiento_fecha_key integer,
    sucursal_key integer,
    producto_key integer,
    lote text,
    stock_disponible integer,
    stock_minimo integer,
    stock_maximo integer,
    fecha_vencimiento date,
    valor_inventario_referencia numeric,
    sin_stock boolean,
    bajo_minimo boolean,
    sobre_maximo boolean,
    dias_para_vencer integer,
    vencido boolean,
    vence_en_30_dias boolean,
    producto text,
    categoria text,
    marca text,
    sucursal text,
    fecha_corte date
);


--
-- Name: rpt_ventas_mensuales; Type: TABLE; Schema: marts; Owner: -
--

CREATE TABLE marts.rpt_ventas_mensuales (
    periodo text,
    sucursal_key integer,
    sucursal text,
    tickets bigint,
    ventas_completadas numeric,
    unidades_vendidas bigint,
    margen_estimado numeric,
    devoluciones_estimadas numeric,
    ventas_ajustadas_estimadas numeric,
    meta_ventas numeric(14,2),
    meta_unidades integer,
    cumplimiento_meta numeric,
    ticket_promedio numeric
);


--
-- Name: categoria; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.categoria (
    id_categoria text,
    nombre text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: cliente; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.cliente (
    id_cliente text,
    nit text,
    nombre text,
    tipo_cliente text,
    municipio text,
    departamento text,
    fecha_alta text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: inventario_bodega; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.inventario_bodega (
    fecha_corte text,
    id_sucursal text,
    id_producto text,
    stock_disponible text,
    stock_minimo text,
    stock_maximo text,
    lote text,
    fecha_vencimiento text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: marca; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.marca (
    id_marca text,
    nombre text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: metas_ventas; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.metas_ventas (
    periodo text,
    id_sucursal text,
    meta_ventas text,
    meta_unidades text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: promociones; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.promociones (
    id_promocion text,
    nombre text,
    fecha_inicio text,
    fecha_fin text,
    id_categoria text,
    porcentaje_descuento text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: proveedores_precios; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.proveedores_precios (
    id_proveedor text,
    proveedor text,
    id_producto text,
    costo_proveedor text,
    plazo_dias text,
    fecha_vigencia text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: sucursal; Type: TABLE; Schema: raw; Owner: -
--

CREATE TABLE raw.sucursal (
    id_sucursal text,
    nombre text,
    ciudad text,
    departamento text,
    _loaded_at timestamp with time zone DEFAULT now() NOT NULL,
    _source text NOT NULL,
    _batch_id uuid NOT NULL,
    _source_row integer NOT NULL
);


--
-- Name: stg_categoria; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_categoria AS
 SELECT (NULLIF(TRIM(BOTH FROM id_categoria), ''::text))::integer AS id_categoria,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.categoria;


--
-- Name: stg_cliente; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_cliente AS
 SELECT (NULLIF(TRIM(BOTH FROM id_cliente), ''::text))::integer AS id_cliente,
    NULLIF(TRIM(BOTH FROM nit), ''::text) AS nit,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    NULLIF(TRIM(BOTH FROM tipo_cliente), ''::text) AS tipo_cliente,
    NULLIF(TRIM(BOTH FROM municipio), ''::text) AS municipio,
    NULLIF(TRIM(BOTH FROM departamento), ''::text) AS departamento,
    (NULLIF(TRIM(BOTH FROM fecha_alta), ''::text))::date AS fecha_alta,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.cliente;


--
-- Name: stg_inventario_bodega; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_inventario_bodega AS
 SELECT (NULLIF(TRIM(BOTH FROM fecha_corte), ''::text))::date AS fecha_corte,
    (NULLIF(TRIM(BOTH FROM id_sucursal), ''::text))::integer AS id_sucursal,
    (NULLIF(TRIM(BOTH FROM id_producto), ''::text))::integer AS id_producto,
    (NULLIF(TRIM(BOTH FROM stock_disponible), ''::text))::integer AS stock_disponible,
    (NULLIF(TRIM(BOTH FROM stock_minimo), ''::text))::integer AS stock_minimo,
    (NULLIF(TRIM(BOTH FROM stock_maximo), ''::text))::integer AS stock_maximo,
    NULLIF(TRIM(BOTH FROM lote), ''::text) AS lote,
    (NULLIF(TRIM(BOTH FROM fecha_vencimiento), ''::text))::date AS fecha_vencimiento,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.inventario_bodega;


--
-- Name: stg_marca; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_marca AS
 SELECT (NULLIF(TRIM(BOTH FROM id_marca), ''::text))::integer AS id_marca,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.marca;


--
-- Name: stg_metas_ventas; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_metas_ventas AS
 SELECT NULLIF(TRIM(BOTH FROM periodo), ''::text) AS periodo,
    (NULLIF(TRIM(BOTH FROM id_sucursal), ''::text))::integer AS id_sucursal,
    (NULLIF(TRIM(BOTH FROM meta_ventas), ''::text))::numeric(14,2) AS meta_ventas,
    (NULLIF(TRIM(BOTH FROM meta_unidades), ''::text))::integer AS meta_unidades,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.metas_ventas;


--
-- Name: stg_promociones; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_promociones AS
 SELECT (NULLIF(TRIM(BOTH FROM id_promocion), ''::text))::integer AS id_promocion,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    (NULLIF(TRIM(BOTH FROM fecha_inicio), ''::text))::date AS fecha_inicio,
    (NULLIF(TRIM(BOTH FROM fecha_fin), ''::text))::date AS fecha_fin,
    (NULLIF(TRIM(BOTH FROM id_categoria), ''::text))::integer AS id_categoria,
    (NULLIF(TRIM(BOTH FROM porcentaje_descuento), ''::text))::numeric(5,4) AS porcentaje_descuento,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.promociones;


--
-- Name: stg_proveedores_precios; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_proveedores_precios AS
 SELECT (NULLIF(TRIM(BOTH FROM id_proveedor), ''::text))::integer AS id_proveedor,
    NULLIF(TRIM(BOTH FROM proveedor), ''::text) AS proveedor,
    (NULLIF(TRIM(BOTH FROM id_producto), ''::text))::integer AS id_producto,
    (NULLIF(TRIM(BOTH FROM costo_proveedor), ''::text))::numeric(12,2) AS costo_proveedor,
    (NULLIF(TRIM(BOTH FROM plazo_dias), ''::text))::integer AS plazo_dias,
    (NULLIF(TRIM(BOTH FROM fecha_vigencia), ''::text))::date AS fecha_vigencia,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.proveedores_precios;


--
-- Name: stg_sucursal; Type: VIEW; Schema: staging; Owner: -
--

CREATE VIEW staging.stg_sucursal AS
 SELECT (NULLIF(TRIM(BOTH FROM id_sucursal), ''::text))::integer AS id_sucursal,
    NULLIF(TRIM(BOTH FROM nombre), ''::text) AS nombre,
    NULLIF(TRIM(BOTH FROM ciudad), ''::text) AS ciudad,
    NULLIF(TRIM(BOTH FROM departamento), ''::text) AS departamento,
    _loaded_at,
    _source,
    _batch_id,
    _source_row
   FROM raw.sucursal;


--
-- Name: load_runs load_runs_pkey; Type: CONSTRAINT; Schema: audit; Owner: -
--

ALTER TABLE ONLY audit.load_runs
    ADD CONSTRAINT load_runs_pkey PRIMARY KEY (batch_id);


--
-- Name: bridge_promocion_venta bridge_promocion_venta_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.bridge_promocion_venta
    ADD CONSTRAINT bridge_promocion_venta_pkey PRIMARY KEY (venta_key, promocion_key);


--
-- Name: dim_canal dim_canal_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_canal
    ADD CONSTRAINT dim_canal_pkey PRIMARY KEY (canal_key);


--
-- Name: dim_cliente dim_cliente_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_cliente
    ADD CONSTRAINT dim_cliente_pkey PRIMARY KEY (cliente_key);


--
-- Name: dim_fecha dim_fecha_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_fecha
    ADD CONSTRAINT dim_fecha_pkey PRIMARY KEY (fecha_key);


--
-- Name: dim_pago dim_pago_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_pago
    ADD CONSTRAINT dim_pago_pkey PRIMARY KEY (pago_key);


--
-- Name: dim_producto dim_producto_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_producto
    ADD CONSTRAINT dim_producto_pkey PRIMARY KEY (producto_key);


--
-- Name: dim_promocion dim_promocion_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_promocion
    ADD CONSTRAINT dim_promocion_pkey PRIMARY KEY (promocion_key);


--
-- Name: dim_proveedor dim_proveedor_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_proveedor
    ADD CONSTRAINT dim_proveedor_pkey PRIMARY KEY (proveedor_key);


--
-- Name: dim_sucursal dim_sucursal_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.dim_sucursal
    ADD CONSTRAINT dim_sucursal_pkey PRIMARY KEY (sucursal_key);


--
-- Name: fact_devoluciones fact_devoluciones_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_devoluciones
    ADD CONSTRAINT fact_devoluciones_pkey PRIMARY KEY (devolucion_key);


--
-- Name: fact_inventario fact_inventario_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_inventario
    ADD CONSTRAINT fact_inventario_pkey PRIMARY KEY (inventario_key);


--
-- Name: fact_metas fact_metas_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_metas
    ADD CONSTRAINT fact_metas_pkey PRIMARY KEY (meta_key);


--
-- Name: fact_proveedor_precio fact_proveedor_precio_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_proveedor_precio
    ADD CONSTRAINT fact_proveedor_precio_pkey PRIMARY KEY (precio_key);


--
-- Name: fact_ventas fact_ventas_pkey; Type: CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_pkey PRIMARY KEY (venta_key);


--
-- Name: categoria categoria__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.categoria
    ADD CONSTRAINT categoria__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: cliente cliente__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.cliente
    ADD CONSTRAINT cliente__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: devoluciones devoluciones__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.devoluciones
    ADD CONSTRAINT devoluciones__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: inventario_bodega inventario_bodega__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.inventario_bodega
    ADD CONSTRAINT inventario_bodega__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: marca marca__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.marca
    ADD CONSTRAINT marca__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: metas_ventas metas_ventas__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.metas_ventas
    ADD CONSTRAINT metas_ventas__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: producto producto__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.producto
    ADD CONSTRAINT producto__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: promociones promociones__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.promociones
    ADD CONSTRAINT promociones__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: proveedores_precios proveedores_precios__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.proveedores_precios
    ADD CONSTRAINT proveedores_precios__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: sucursal sucursal__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.sucursal
    ADD CONSTRAINT sucursal__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: venta venta__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.venta
    ADD CONSTRAINT venta__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: venta_detalle venta_detalle__batch_id__source_row_key; Type: CONSTRAINT; Schema: raw; Owner: -
--

ALTER TABLE ONLY raw.venta_detalle
    ADD CONSTRAINT venta_detalle__batch_id__source_row_key UNIQUE (_batch_id, _source_row);


--
-- Name: bridge_promocion_venta bridge_promocion_venta_promocion_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.bridge_promocion_venta
    ADD CONSTRAINT bridge_promocion_venta_promocion_key_fkey FOREIGN KEY (promocion_key) REFERENCES marts.dim_promocion(promocion_key);


--
-- Name: bridge_promocion_venta bridge_promocion_venta_venta_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.bridge_promocion_venta
    ADD CONSTRAINT bridge_promocion_venta_venta_key_fkey FOREIGN KEY (venta_key) REFERENCES marts.fact_ventas(venta_key);


--
-- Name: fact_devoluciones fact_devoluciones_cliente_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_devoluciones
    ADD CONSTRAINT fact_devoluciones_cliente_key_fkey FOREIGN KEY (cliente_key) REFERENCES marts.dim_cliente(cliente_key);


--
-- Name: fact_devoluciones fact_devoluciones_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_devoluciones
    ADD CONSTRAINT fact_devoluciones_fecha_key_fkey FOREIGN KEY (fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_devoluciones fact_devoluciones_producto_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_devoluciones
    ADD CONSTRAINT fact_devoluciones_producto_key_fkey FOREIGN KEY (producto_key) REFERENCES marts.dim_producto(producto_key);


--
-- Name: fact_devoluciones fact_devoluciones_sucursal_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_devoluciones
    ADD CONSTRAINT fact_devoluciones_sucursal_key_fkey FOREIGN KEY (sucursal_key) REFERENCES marts.dim_sucursal(sucursal_key);


--
-- Name: fact_inventario fact_inventario_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_inventario
    ADD CONSTRAINT fact_inventario_fecha_key_fkey FOREIGN KEY (fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_inventario fact_inventario_producto_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_inventario
    ADD CONSTRAINT fact_inventario_producto_key_fkey FOREIGN KEY (producto_key) REFERENCES marts.dim_producto(producto_key);


--
-- Name: fact_inventario fact_inventario_sucursal_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_inventario
    ADD CONSTRAINT fact_inventario_sucursal_key_fkey FOREIGN KEY (sucursal_key) REFERENCES marts.dim_sucursal(sucursal_key);


--
-- Name: fact_inventario fact_inventario_vencimiento_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_inventario
    ADD CONSTRAINT fact_inventario_vencimiento_fecha_key_fkey FOREIGN KEY (vencimiento_fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_metas fact_metas_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_metas
    ADD CONSTRAINT fact_metas_fecha_key_fkey FOREIGN KEY (fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_metas fact_metas_sucursal_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_metas
    ADD CONSTRAINT fact_metas_sucursal_key_fkey FOREIGN KEY (sucursal_key) REFERENCES marts.dim_sucursal(sucursal_key);


--
-- Name: fact_proveedor_precio fact_proveedor_precio_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_proveedor_precio
    ADD CONSTRAINT fact_proveedor_precio_fecha_key_fkey FOREIGN KEY (fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_proveedor_precio fact_proveedor_precio_producto_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_proveedor_precio
    ADD CONSTRAINT fact_proveedor_precio_producto_key_fkey FOREIGN KEY (producto_key) REFERENCES marts.dim_producto(producto_key);


--
-- Name: fact_proveedor_precio fact_proveedor_precio_proveedor_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_proveedor_precio
    ADD CONSTRAINT fact_proveedor_precio_proveedor_key_fkey FOREIGN KEY (proveedor_key) REFERENCES marts.dim_proveedor(proveedor_key);


--
-- Name: fact_ventas fact_ventas_canal_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_canal_key_fkey FOREIGN KEY (canal_key) REFERENCES marts.dim_canal(canal_key);


--
-- Name: fact_ventas fact_ventas_cliente_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_cliente_key_fkey FOREIGN KEY (cliente_key) REFERENCES marts.dim_cliente(cliente_key);


--
-- Name: fact_ventas fact_ventas_fecha_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_fecha_key_fkey FOREIGN KEY (fecha_key) REFERENCES marts.dim_fecha(fecha_key);


--
-- Name: fact_ventas fact_ventas_pago_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_pago_key_fkey FOREIGN KEY (pago_key) REFERENCES marts.dim_pago(pago_key);


--
-- Name: fact_ventas fact_ventas_producto_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_producto_key_fkey FOREIGN KEY (producto_key) REFERENCES marts.dim_producto(producto_key);


--
-- Name: fact_ventas fact_ventas_sucursal_key_fkey; Type: FK CONSTRAINT; Schema: marts; Owner: -
--

ALTER TABLE ONLY marts.fact_ventas
    ADD CONSTRAINT fact_ventas_sucursal_key_fkey FOREIGN KEY (sucursal_key) REFERENCES marts.dim_sucursal(sucursal_key);


--
-- PostgreSQL database dump complete
--

\unrestrict izJF0dSbho7COmVn05DJIYY7AsjmYodNEh7lGiV2DdyKp3zsYbBa2AschYgEWZp

