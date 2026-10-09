-- Raw preserva valores originales; los tipos y reglas se aplican en dbt.

CREATE SCHEMA IF NOT EXISTS raw;

CREATE SCHEMA IF NOT EXISTS audit;

CREATE TABLE IF NOT EXISTS audit.load_runs (
      batch_id UUID PRIMARY KEY, started_at TIMESTAMPTZ NOT NULL,
      completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      counts JSONB NOT NULL, file_hashes JSONB NOT NULL
    );

CREATE TABLE IF NOT EXISTS raw.sucursal (
    "id_sucursal" TEXT,
    "nombre" TEXT,
    "ciudad" TEXT,
    "departamento" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.categoria (
    "id_categoria" TEXT,
    "nombre" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.marca (
    "id_marca" TEXT,
    "nombre" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.producto (
    "id_producto" TEXT,
    "sku" TEXT,
    "nombre" TEXT,
    "id_categoria" TEXT,
    "id_marca" TEXT,
    "unidad_medida" TEXT,
    "costo_base" TEXT,
    "precio_lista" TEXT,
    "activo" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.cliente (
    "id_cliente" TEXT,
    "nit" TEXT,
    "nombre" TEXT,
    "tipo_cliente" TEXT,
    "municipio" TEXT,
    "departamento" TEXT,
    "fecha_alta" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.venta (
    "id_venta" TEXT,
    "fecha" TEXT,
    "id_cliente" TEXT,
    "id_sucursal" TEXT,
    "canal" TEXT,
    "metodo_pago" TEXT,
    "estado" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.venta_detalle (
    "id_detalle" TEXT,
    "id_venta" TEXT,
    "id_producto" TEXT,
    "cantidad" TEXT,
    "precio_unitario" TEXT,
    "descuento" TEXT,
    "subtotal" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.inventario_bodega (
    "fecha_corte" TEXT,
    "id_sucursal" TEXT,
    "id_producto" TEXT,
    "stock_disponible" TEXT,
    "stock_minimo" TEXT,
    "stock_maximo" TEXT,
    "lote" TEXT,
    "fecha_vencimiento" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.proveedores_precios (
    "id_proveedor" TEXT,
    "proveedor" TEXT,
    "id_producto" TEXT,
    "costo_proveedor" TEXT,
    "plazo_dias" TEXT,
    "fecha_vigencia" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.promociones (
    "id_promocion" TEXT,
    "nombre" TEXT,
    "fecha_inicio" TEXT,
    "fecha_fin" TEXT,
    "id_categoria" TEXT,
    "porcentaje_descuento" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.metas_ventas (
    "periodo" TEXT,
    "id_sucursal" TEXT,
    "meta_ventas" TEXT,
    "meta_unidades" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );

CREATE TABLE IF NOT EXISTS raw.devoluciones (
    "id_devolucion" TEXT,
    "fecha" TEXT,
    "id_venta" TEXT,
    "id_producto" TEXT,
    "cantidad" TEXT,
    "motivo" TEXT,
    _loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    _source TEXT NOT NULL, _batch_id UUID NOT NULL, _source_row INTEGER NOT NULL,
    UNIQUE (_batch_id, _source_row)
    );
