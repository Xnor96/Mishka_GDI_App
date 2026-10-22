import 'package:flutter/foundation.dart';

/// Una línea dentro de una venta (producto + cantidad + precio).
/// El modelo también sirve para representar salidas sueltas en reportes.
@immutable
class Salida {
  final int      id;
  final int?     idVenta;        // null solo en datos pre-migración v1
  final int      idProducto;
  final String   codigoProducto;
  final String   nombreProducto;
  final String   nombreCategoria;
  final DateTime fechaSalida;
  final int      cantidad;
  final double   precioVenta;
  final double   descuento;      // legacy; en ventas nuevas es 0
  final double   total;          // precio_venta * cantidad - descuento
  final String   lugarVenta;
  final String   tipoPago;
  final String   observaciones;
  final String   usuarioRegistro;

  const Salida({
    required this.id,
    this.idVenta,
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
    idVenta:         j['id_venta']         as int?,
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

/// Una venta completa — N líneas que comparten lugar/tipo_pago/fecha.
@immutable
class Venta {
  final int           id;
  final DateTime      fechaVenta;
  final String        lugarVenta;
  final String        tipoPago;
  final double        total;         // suma de los totales de líneas
  final String        observaciones;
  final String        usuarioRegistro;
  final List<Salida>  lineas;

  const Venta({
    required this.id,
    required this.fechaVenta,
    required this.lugarVenta,
    required this.tipoPago,
    required this.total,
    required this.observaciones,
    required this.usuarioRegistro,
    required this.lineas,
  });

  int    get cantidadItems => lineas.fold(0, (s, l) => s + l.cantidad);
  int    get numLineas     => lineas.length;
  String get resumenProductos {
    if (lineas.isEmpty) return '';
    if (lineas.length == 1) return lineas.first.nombreProducto;
    return '${lineas.first.nombreProducto} + ${lineas.length - 1} más';
  }

  factory Venta.fromJson(Map<String, dynamic> j, List<Salida> lineas) => Venta(
    id:              j['id_venta']         as int,
    fechaVenta:      DateTime.parse(j['fecha_venta'] as String),
    lugarVenta:      j['lugar_venta']      as String,
    tipoPago:        j['tipo_pago']        as String,
    total:           (j['total']           as num).toDouble(),
    observaciones:   j['observaciones']    as String,
    usuarioRegistro: j['usuario_registro'] as String,
    lineas:          lineas,
  );
}

/// Línea en el "carrito" del form (todavía no persistida).
/// Se transforma a salida_producto al confirmar la venta.
class LineaCarrito {
  final int    idProducto;
  final String codigo;
  final String nombre;
  final String categoria;
  final int    stockDisponible;
  int    cantidad;
  double precioUnitario;

  LineaCarrito({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.stockDisponible,
    required this.cantidad,
    required this.precioUnitario,
  });

  double get subtotal => cantidad * precioUnitario;
}
