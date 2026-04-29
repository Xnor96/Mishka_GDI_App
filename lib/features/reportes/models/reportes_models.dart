import 'package:flutter/foundation.dart';

// ── Inventario valorado ───────────────────────────────────────────────────────
@immutable
class ReporteInventarioItem {
  final int    idProducto;
  final String codigo;
  final String nombre;
  final String categoria;
  final String unidadMedida;
  final double precioUnitario;
  final int    stockActual;
  final double valorTotal;

  const ReporteInventarioItem({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.unidadMedida,
    required this.precioUnitario,
    required this.stockActual,
    required this.valorTotal,
  });

  factory ReporteInventarioItem.fromJson(Map<String, dynamic> j) =>
      ReporteInventarioItem(
        idProducto:     j['id_producto']    as int,
        codigo:         j['codigo']         as String,
        nombre:         j['nombre']         as String,
        categoria:      j['categoria']      as String,
        unidadMedida:   j['unidad_medida']  as String,
        precioUnitario: (j['precio_unitario'] as num).toDouble(),
        stockActual:    j['stock_actual']   as int,
        valorTotal:     (j['valor_total']   as num).toDouble(),
      );
}

// ── Movimientos ───────────────────────────────────────────────────────────────
@immutable
class ReporteMovimientoItem {
  final DateTime fecha;
  final String   tipo; // ENTRADA | SALIDA
  final String   codigo;
  final String   nombre;
  final String   categoria;
  final int      cantidad;
  final double   precio;
  final double   total;
  final String   lugarVenta;
  final String   tipoPago;

  const ReporteMovimientoItem({
    required this.fecha,
    required this.tipo,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.cantidad,
    required this.precio,
    required this.total,
    required this.lugarVenta,
    required this.tipoPago,
  });

  factory ReporteMovimientoItem.fromJson(Map<String, dynamic> j) =>
      ReporteMovimientoItem(
        fecha:      DateTime.parse(j['fecha'] as String),
        tipo:       j['tipo']       as String,
        codigo:     j['codigo']     as String,
        nombre:     j['nombre']     as String,
        categoria:  j['categoria']  as String,
        cantidad:   j['cantidad']   as int,
        precio:     (j['precio']    as num).toDouble(),
        total:      (j['total']     as num).toDouble(),
        lugarVenta: j['lugar_venta'] as String? ?? '',
        tipoPago:   j['tipo_pago']   as String? ?? '',
      );
}

// ── Más vendidos ──────────────────────────────────────────────────────────────
@immutable
class ReporteVendidoItem {
  final int    idProducto;
  final String codigo;
  final String nombre;
  final String categoria;
  final int    totalVendido;
  final double totalIngresos;

  const ReporteVendidoItem({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.totalVendido,
    required this.totalIngresos,
  });

  factory ReporteVendidoItem.fromJson(Map<String, dynamic> j) =>
      ReporteVendidoItem(
        idProducto:    j['id_producto']    as int,
        codigo:        j['codigo']         as String,
        nombre:        j['nombre']         as String,
        categoria:     j['categoria']      as String,
        totalVendido:  j['total_vendido']  as int,
        totalIngresos: (j['total_ingresos'] as num).toDouble(),
      );
}

// ── Valoración por categoría ──────────────────────────────────────────────────
@immutable
class ReporteValoracionItem {
  final int    idCategoria;
  final String nombreCategoria;
  final int    totalProductos;
  final int    totalUnidades;
  final double valorTotal;

  const ReporteValoracionItem({
    required this.idCategoria,
    required this.nombreCategoria,
    required this.totalProductos,
    required this.totalUnidades,
    required this.valorTotal,
  });

  factory ReporteValoracionItem.fromJson(Map<String, dynamic> j) =>
      ReporteValoracionItem(
        idCategoria:     j['id_categoria']     as int,
        nombreCategoria: j['nombre_categoria'] as String,
        totalProductos:  j['total_productos']  as int,
        totalUnidades:   j['total_unidades']   as int,
        valorTotal:      (j['valor_total']     as num).toDouble(),
      );
}
