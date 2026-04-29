import 'package:flutter/foundation.dart';

/// Espejo de SalidaProductoResponse del backend.
@immutable
class Salida {
  final int      id;
  final int      idProducto;
  final String   codigoProducto;
  final String   nombreProducto;
  final String   nombreCategoria;
  final DateTime fechaSalida;
  final int      cantidad;
  final double   precioVenta;
  final double   descuento;
  final double   total;
  final String   lugarVenta;
  final String   tipoPago;
  final String   observaciones;
  final String   usuarioRegistro;

  const Salida({
    required this.id,
    required this.idProducto,
    required this.codigoProducto,
    required this.nombreProducto,
    required this.nombreCategoria,
    required this.fechaSalida,
    required this.cantidad,
    required this.precioVenta,
    required this.descuento,
    required this.total,
    required this.lugarVenta,
    required this.tipoPago,
    required this.observaciones,
    required this.usuarioRegistro,
  });

  factory Salida.fromJson(Map<String, dynamic> j) => Salida(
    id:              j['id_salida']        as int,
    idProducto:      j['id_producto']      as int,
    codigoProducto:  j['codigo_producto']  as String,
    nombreProducto:  j['nombre_producto']  as String,
    nombreCategoria: j['nombre_categoria'] as String,
    fechaSalida:     DateTime.parse(j['fecha_salida'] as String),
    cantidad:        j['cantidad']         as int,
    precioVenta:     (j['precio_venta']    as num).toDouble(),
    descuento:       (j['descuento']       as num).toDouble(),
    total:           (j['total']           as num).toDouble(),
    lugarVenta:      j['lugar_venta']      as String,
    tipoPago:        j['tipo_pago']        as String,
    observaciones:   j['observaciones']    as String,
    usuarioRegistro: j['usuario_registro'] as String,
  );
}
