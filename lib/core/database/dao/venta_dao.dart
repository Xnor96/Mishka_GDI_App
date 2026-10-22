import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// DAO de ventas (header + líneas). Una venta tiene UN lugar, UN tipo de pago,
/// UNA fecha y N líneas (cada línea = un producto con cantidad y precio).
///
/// Registro:
///   - `registrar(venta, lineas)` crea el header + N líneas + descuenta stock
///     de cada producto, todo en UNA transacción. Si falta stock en alguna
///     línea, revierte todo y lanza error.
/// Eliminación:
///   - `eliminar(idVenta)` recupera las líneas, elimina la venta (CASCADE
///     borra las líneas) y suma el stock de vuelta a cada producto.
class VentaDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  /// Lista todas las ventas con sus líneas, cada una como un Map con
  /// la forma esperada por Venta.fromJson. Las líneas vienen como
  /// `List<Map>` dentro del campo `_lineas` (el provider las extrae).
  Future<List<Map<String, dynamic>>> listar({
    String? filtroLugar,
    DateTime? desde,
    DateTime? hasta,
  }) async {
    final db = await _db;
    final wheres = <String>[];
    final args   = <Object?>[];
    if (filtroLugar != null && filtroLugar.isNotEmpty) {
      wheres.add('v.lugar_venta = ?');
      args.add(filtroLugar);
    }
    if (desde != null) {
      wheres.add('v.fecha_venta >= ?');
      args.add(_dateOnly(desde));
    }
    if (hasta != null) {
      wheres.add('v.fecha_venta <= ?');
      args.add(_dateOnly(hasta));
    }
    final where = wheres.isEmpty ? '' : 'WHERE ${wheres.join(' AND ')}';

    // Traemos los headers primero
    final headers = await db.rawQuery('''
      SELECT id_venta, fecha_venta, lugar_venta, tipo_pago, total,
             observaciones, usuario_registro
      FROM ventas v
      $where
      ORDER BY v.fecha_venta DESC, v.id_venta DESC
    ''', args);

    if (headers.isEmpty) return [];

    // Traemos todas las líneas de esas ventas en una sola query
    final ids = headers.map((h) => h['id_venta']).join(',');
    final lineas = await db.rawQuery('''
      SELECT
        s.id_salida,
        s.id_venta,
        s.id_producto,
        p.codigo               AS codigo_producto,
        p.nombre               AS nombre_producto,
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
      JOIN productos p ON p.id_producto = s.id_producto
      LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
      WHERE s.id_venta IN ($ids)
      ORDER BY s.id_salida ASC
    ''');

    // Agrupar líneas por id_venta
    final porVenta = <int, List<Map<String, dynamic>>>{};
    for (final l in lineas) {
      final idV = l['id_venta'] as int;
      (porVenta[idV] ??= []).add(l);
    }

    // Combinar
    return [
      for (final h in headers)
        {
          ...h,
          '_lineas': porVenta[h['id_venta']] ?? const <Map<String, dynamic>>[],
        }
    ];
  }

  /// Registra una venta nueva. [venta] trae el header; [lineas] la lista de
  /// productos con cantidad y precio. Devuelve el id de la venta creada.
  /// Lanza StateError si falta stock en alguna línea.
  Future<int> registrar(
    Map<String, dynamic> venta,
    List<Map<String, dynamic>> lineas,
  ) async {
    if (lineas.isEmpty) {
      throw StateError('La venta no tiene productos');
    }
    final db = await _db;
    return db.transaction<int>((tx) async {
      final fecha  = venta['fecha_venta']   as String;
      final lugar  = (venta['lugar_venta']  ?? '') as String;
      final pago   = (venta['tipo_pago']    ?? '') as String;
      final obs    = (venta['observaciones']    ?? '') as String;
      final user   = (venta['usuario_registro'] ?? 'sistema') as String;

      // 1. Validar stock de todas las líneas ANTES de tocar nada
      double totalVenta = 0;
      for (final l in lineas) {
        final idProducto = l['id_producto'] as int;
        final cantidad   = l['cantidad']    as int;
        final precio     = (l['precio_venta'] as num).toDouble();
        final subtotal   = precio * cantidad;
        totalVenta += subtotal;

        final r = await tx.rawQuery(
          'SELECT nombre, stock_actual FROM productos WHERE id_producto = ?',
          [idProducto],
        );
        if (r.isEmpty) {
          throw StateError('Producto $idProducto no existe');
        }
        final stock = r.first['stock_actual'] as int;
        if (stock < cantidad) {
          final nombre = r.first['nombre'] as String;
          throw StateError(
              'Stock insuficiente para "$nombre" (hay $stock, piden $cantidad)');
        }
      }

      // 2. Insertar el header
      final idVenta = await tx.insert('ventas', {
        'fecha_venta':      fecha,
        'lugar_venta':      lugar,
        'tipo_pago':        pago,
        'total':            totalVenta,
        'observaciones':    obs,
        'usuario_registro': user,
      });

      // 3. Insertar cada línea + descontar stock
      for (final l in lineas) {
        final idProducto = l['id_producto'] as int;
        final cantidad   = l['cantidad']    as int;
        final precio     = (l['precio_venta'] as num).toDouble();
        final subtotal   = precio * cantidad;

        await tx.insert('salidas_productos', {
          'id_venta':         idVenta,
          'id_producto':      idProducto,
          'fecha_salida':     fecha,
          'cantidad':         cantidad,
          'precio_venta':     precio,
          'descuento':        0.0,
          'total':            subtotal,
          'lugar_venta':      lugar,
          'tipo_pago':        pago,
          'observaciones':    '',
          'usuario_registro': user,
        });

        await tx.rawUpdate(
          'UPDATE productos SET stock_actual = stock_actual - ? WHERE id_producto = ?',
          [cantidad, idProducto],
        );
      }

      return idVenta;
    });
  }

  /// Elimina una venta y revierte el stock de todas sus líneas.
  Future<void> eliminar(int idVenta) async {
    final db = await _db;
    await db.transaction((tx) async {
      // Leer líneas para saber qué stock devolver
      final lineas = await tx.query('salidas_productos',
          where: 'id_venta = ?', whereArgs: [idVenta]);

      // Borrar el header (CASCADE borraría las líneas en principio, pero en
      // esta BD la columna id_venta no tiene FK ENFORCED porque se agregó
      // por ALTER TABLE — borramos manualmente para ser explícitos)
      await tx.delete('salidas_productos',
          where: 'id_venta = ?', whereArgs: [idVenta]);
      await tx.delete('ventas',
          where: 'id_venta = ?', whereArgs: [idVenta]);

      // Devolver stock
      for (final l in lineas) {
        final idProducto = l['id_producto'] as int;
        final cantidad   = l['cantidad']    as int;
        await tx.rawUpdate(
          'UPDATE productos SET stock_actual = stock_actual + ? WHERE id_producto = ?',
          [cantidad, idProducto],
        );
      }
    });
  }

  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
