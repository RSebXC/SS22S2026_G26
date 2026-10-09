"""Contrato explícito de columnas de las fuentes suministradas."""
OLTP = {
    'sucursal': 'id_sucursal:int,nombre:text,ciudad:text,departamento:text',
    'categoria': 'id_categoria:int,nombre:text',
    'marca': 'id_marca:int,nombre:text',
    'producto': 'id_producto:int,sku:text,nombre:text,id_categoria:int,id_marca:int,unidad_medida:text,costo_base:numeric(12|2),precio_lista:numeric(12|2),activo:boolean',
    'cliente': 'id_cliente:int,nit:text,nombre:text,tipo_cliente:text,municipio:text,departamento:text,fecha_alta:date',
    'venta': 'id_venta:bigint,fecha:date,id_cliente:int,id_sucursal:int,canal:text,metodo_pago:text,estado:text',
    'venta_detalle': 'id_detalle:bigint,id_venta:bigint,id_producto:int,cantidad:int,precio_unitario:numeric(12|2),descuento:numeric(5|4),subtotal:numeric(14|2)',
}
CSV = {
    'inventario_bodega': 'fecha_corte:date,id_sucursal:int,id_producto:int,stock_disponible:int,stock_minimo:int,stock_maximo:int,lote:text,fecha_vencimiento:date',
    'proveedores_precios': 'id_proveedor:int,proveedor:text,id_producto:int,costo_proveedor:numeric(12|2),plazo_dias:int,fecha_vigencia:date',
    'promociones': 'id_promocion:int,nombre:text,fecha_inicio:date,fecha_fin:date,id_categoria:int,porcentaje_descuento:numeric(5|4)',
    'metas_ventas': 'periodo:text,id_sucursal:int,meta_ventas:numeric(14|2),meta_unidades:int',
    'devoluciones': 'id_devolucion:bigint,fecha:date,id_venta:bigint,id_producto:int,cantidad:int,motivo:text',
}
TABLES = {
    name: [(item.split(':')[0], item.split(':')[1].replace('|', ',')) for item in spec.split(',')]
    for name, spec in {**OLTP, **CSV}.items()
}
