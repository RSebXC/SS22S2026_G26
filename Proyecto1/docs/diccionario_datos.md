# Diccionario de datos original

Extraído de catalogo_insumos_sgfood.xlsx. Se conserva el contenido documental; los conteos observados se registran por separado.

## Resumen

| Archivo | Formato | Rol | Contenido | Registros aprox. | Uso sugerido |
| --- | --- | --- | --- | --- | --- |
| sgfood_oltp.sql | PostgreSQL | Fuente transaccional | DDL + datos OLTP | 1200 | Ejecutar en BD fuente |
| inventario_bodega.csv | CSV | Fuente externa | Inventario mensual | 3840 | Cargar con Python a raw |
| proveedores_precios.csv | CSV | Fuente externa | Costos y plazos | 103 | Cargar con Python a raw |
| promociones.csv | CSV | Fuente externa | Campañas comerciales | 30 | Cargar con Python a raw |
| metas_ventas.csv | CSV | Fuente externa | Metas mensuales | 48 | Cargar con Python a raw |
| devoluciones.csv | CSV | Fuente externa | Devoluciones | 80 | Cargar con Python a raw |
| casos_calidad_opcionales.csv | CSV | Pruebas | Datos inválidos intencionales | 10 | No cargar en corrida principal |

## Diccionario

| Fuente | Entidad/Archivo | Campo | Tipo | Clave/Regla | Descripción |
| --- | --- | --- | --- | --- | --- |
| PostgreSQL OLTP | sucursal | id_sucursal | INTEGER | PK | Identificador de sucursal |
| PostgreSQL OLTP | sucursal | nombre | VARCHAR |  | Nombre comercial |
| PostgreSQL OLTP | sucursal | ciudad | VARCHAR |  | Ciudad |
| PostgreSQL OLTP | sucursal | departamento | VARCHAR |  | Departamento |
| PostgreSQL OLTP | categoria | id_categoria | INTEGER | PK | Identificador de categoría |
| PostgreSQL OLTP | categoria | nombre | VARCHAR | UQ | Nombre de categoría |
| PostgreSQL OLTP | marca | id_marca | INTEGER | PK | Identificador de marca |
| PostgreSQL OLTP | marca | nombre | VARCHAR | UQ | Nombre de marca |
| PostgreSQL OLTP | producto | id_producto | INTEGER | PK | Identificador de producto |
| PostgreSQL OLTP | producto | sku | VARCHAR | UQ | Código SKU |
| PostgreSQL OLTP | producto | nombre | VARCHAR |  | Nombre |
| PostgreSQL OLTP | producto | id_categoria | INTEGER | FK categoria | Categoría |
| PostgreSQL OLTP | producto | id_marca | INTEGER | FK marca | Marca |
| PostgreSQL OLTP | producto | unidad_medida | VARCHAR |  | Unidad |
| PostgreSQL OLTP | producto | costo_base | NUMERIC(12,2) |  | Costo de referencia |
| PostgreSQL OLTP | producto | precio_lista | NUMERIC(12,2) |  | Precio de lista |
| PostgreSQL OLTP | producto | activo | BOOLEAN |  | Estado |
| PostgreSQL OLTP | cliente | id_cliente | INTEGER | PK | Identificador |
| PostgreSQL OLTP | cliente | nit | VARCHAR |  | NIT ficticio |
| PostgreSQL OLTP | cliente | nombre | VARCHAR |  | Nombre ficticio |
| PostgreSQL OLTP | cliente | tipo_cliente | VARCHAR |  | Segmento |
| PostgreSQL OLTP | cliente | municipio | VARCHAR |  | Municipio |
| PostgreSQL OLTP | cliente | departamento | VARCHAR |  | Departamento |
| PostgreSQL OLTP | cliente | fecha_alta | DATE |  | Alta |
| PostgreSQL OLTP | venta | id_venta | BIGINT | PK | Venta |
| PostgreSQL OLTP | venta | fecha | DATE |  | Fecha |
| PostgreSQL OLTP | venta | id_cliente | INTEGER | FK cliente | Cliente |
| PostgreSQL OLTP | venta | id_sucursal | INTEGER | FK sucursal | Sucursal |
| PostgreSQL OLTP | venta | canal | VARCHAR |  | Canal |
| PostgreSQL OLTP | venta | metodo_pago | VARCHAR |  | Método |
| PostgreSQL OLTP | venta | estado | VARCHAR |  | Estado |
| PostgreSQL OLTP | venta_detalle | id_detalle | BIGINT | PK | Línea |
| PostgreSQL OLTP | venta_detalle | id_venta | BIGINT | FK venta | Venta |
| PostgreSQL OLTP | venta_detalle | id_producto | INTEGER | FK producto | Producto |
| PostgreSQL OLTP | venta_detalle | cantidad | INTEGER |  | Unidades |
| PostgreSQL OLTP | venta_detalle | precio_unitario | NUMERIC(12,2) |  | Precio |
| PostgreSQL OLTP | venta_detalle | descuento | NUMERIC(5,4) |  | 0 a 1 |
| PostgreSQL OLTP | venta_detalle | subtotal | NUMERIC(14,2) |  | Importe neto |
| CSV | inventario_bodega.csv | fecha_corte | DATE |  | Snapshot |
| CSV | inventario_bodega.csv | id_sucursal | INTEGER | FK lógica | Sucursal |
| CSV | inventario_bodega.csv | id_producto | INTEGER | FK lógica | Producto |
| CSV | inventario_bodega.csv | stock_disponible | INTEGER |  | Existencia |
| CSV | inventario_bodega.csv | stock_minimo | INTEGER |  | Mínimo |
| CSV | inventario_bodega.csv | stock_maximo | INTEGER |  | Máximo |
| CSV | inventario_bodega.csv | lote | VARCHAR |  | Lote |
| CSV | inventario_bodega.csv | fecha_vencimiento | DATE |  | Vencimiento |
| CSV | proveedores_precios.csv | id_proveedor | INTEGER |  | Proveedor |
| CSV | proveedores_precios.csv | proveedor | VARCHAR |  | Nombre |
| CSV | proveedores_precios.csv | id_producto | INTEGER | FK lógica | Producto |
| CSV | proveedores_precios.csv | costo_proveedor | NUMERIC(12,2) |  | Costo |
| CSV | proveedores_precios.csv | plazo_dias | INTEGER |  | Lead time |
| CSV | proveedores_precios.csv | fecha_vigencia | DATE |  | Vigencia |
| CSV | promociones.csv | id_promocion | INTEGER | PK lógica | Promoción |
| CSV | promociones.csv | nombre | VARCHAR |  | Campaña |
| CSV | promociones.csv | fecha_inicio | DATE |  | Inicio |
| CSV | promociones.csv | fecha_fin | DATE |  | Fin |
| CSV | promociones.csv | id_categoria | INTEGER | FK lógica | Categoría |
| CSV | promociones.csv | porcentaje_descuento | NUMERIC(5,4) |  | 0 a 1 |
| CSV | metas_ventas.csv | periodo | VARCHAR(7) |  | YYYY-MM |
| CSV | metas_ventas.csv | id_sucursal | INTEGER | FK lógica | Sucursal |
| CSV | metas_ventas.csv | meta_ventas | NUMERIC(14,2) |  | Meta monetaria |
| CSV | metas_ventas.csv | meta_unidades | INTEGER |  | Meta de unidades |
| CSV | devoluciones.csv | id_devolucion | INTEGER | PK lógica | Devolución |
| CSV | devoluciones.csv | fecha | DATE |  | Fecha |
| CSV | devoluciones.csv | id_venta | BIGINT | FK lógica | Venta |
| CSV | devoluciones.csv | id_producto | INTEGER | FK lógica | Producto |
| CSV | devoluciones.csv | cantidad | INTEGER |  | Cantidad |
| CSV | devoluciones.csv | motivo | VARCHAR |  | Motivo |

## Diferencia observada

El resumen del catálogo anuncia aproximadamente 3,840 líneas de venta. El SQL contiene 3,209 filas en venta_detalle; se usa el SQL como fuente de verdad. El inventario sí contiene 3,840 posiciones. No se crean registros para completar el conteo aproximado.
