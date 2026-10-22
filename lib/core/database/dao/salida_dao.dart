import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// DAO de salidas (ventas). Al registrar, descuenta stock validando que haya
/// disponible. Al eliminar, revierte el stock.
class SalidaDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  /// Lista todas las líneas sueltas (una fila por producto vendido).
  /// Útil para reportes; para la pantalla de Ventas conviene usar VentaDao.
  Future<List<Map<String, dynamic>>> listar() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        s.id_salida,
        s.id_venta,
        s.id_producto,
        p.codigo   AS codigo_producto,
        p.nombre   AS nombre_producto,
        COALESCE(c.nombre, '') AS nombre_categoria,
        s.fecha_salida,
        s.cantidad,
        s.precio_venta,
        s.descuento,
        s.total,
        s.lugar_venta,
        s.tipo_pago,
        s.observaciones,
        s.usuario_registro
      FROM salidas_productos s
      JOIN productos  p ON p.id_producto  = s.id_producto
      LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
      ORDER BY s.fecha_salida DESC, s.id_salida DESC
    ''');
  }

  /// Lista las líneas que pertenecen a una venta específica.
  Future<List<Map<String, dynamic>>> porVenta(int idVenta) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        s.id_salida,
        s.id_venta,
        s.id_producto,
        p.codigo   AS codigo_producto,
        p.nombre   AS nombre_producto,
        COALESCE(c.nombre, '') AS nombre_categoria,
        s.fecha_salida,
        s.cantidad,
        s.precio_venta,
        s.descuento,
        s.total,
        s.lugar_venta,
        s.tipo_pago,
        s.observaciones,
        s.usuario_registro
      FROM salidas_productos s
      JOIN productos  p ON p.id_producto  = s.id_producto
      LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
      WHERE s.id_venta = ?
      ORDER BY s.id_salida ASC
    ''', [idVenta]);
  }

  Future<int> registrar(Map<String, dynamic> body) async {
    final db = await _db;
    return db.transaction<int>((tx) async {
      final idProducto = body['id_producto'] as int;
      final cantidad   = body['cantidad']    as int;
      final precio     = (body['precio_venta'] as num).toDouble();
      final descuento  = (body['descuento']    ?? 0).toDouble();
      final total      = (precio * cantidad - descuento).clamp(0.0, double.infinity);

      // Validar stock disponible
      final s = await tx.rawQuery(
        'SELECT stock_actual FROM productos WHERE id_producto = ?',
        [idProducto],
      );
      if (s.isEmpty) {
        throw StateError('Producto no existe');
      }
      final stock = s.first['stock_actual'] as int;
      if (stock < cantidad) {
        throw StateError('Stock insuficiente (disponible: $stock)');
      }

      final id = await tx.insert('salidas_productos', {
        'id_producto':      idProducto,
        'fecha_salida':     body['fecha_salida'],
        'cantidad':         cantidad,
        'precio_venta':     precio,
        'descuento':        descuento,
        'total':            total,
        'lugar_venta':      (body['lugar_venta']       ?? '') as String,
        'tipo_pago':        (body['tipo_pago']         ?? '') as String,
        'observaciones':    (body['observaciones']     ?? '') as String,
        'usuario_registro': (body['usuario_registro']  ?? 'sistema') as String,
      });

      await tx.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual - ? WHERE id_producto = ?',
        [cantidad, idProducto],
      );

      return id;
    });
  }

  Future<void> eliminar(int idSalida) async {
    final db = await _db;
    await db.transaction((tx) async {
      final rows = await tx.query('salidas_productos',
          where: 'id_salida = ?', whereArgs: [idSalida], limit: 1);
      if (rows.isEmpty) return;
      final s = rows.first;
      final idProducto = s['id_producto'] as int;
      final cantidad   = s['cantidad']    as int;

      await tx.delete('salidas_productos',
          where: 'id_salida = ?', whereArgs: [idSalida]);

      // Revertir stock (sumar lo que se había restado)
      await tx.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ? WHERE id_producto = ?',
        [cantidad, idProducto],
      );
    });
  }
}
