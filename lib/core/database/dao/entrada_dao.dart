import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'dao_helpers.dart';

/// DAO de entradas de inventario.
/// Todas las inserciones/eliminaciones ajustan `productos.stock_actual`
/// dentro de una transacción (equivalente a los triggers de Postgres).
class EntradaDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  /// Devuelve la lista completa con join a producto+categoría para que la
  /// forma coincida con Entrada.fromJson (codigo_producto, nombre_producto,
  /// nombre_categoria).
  Future<List<Map<String, dynamic>>> listar() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT
        e.id_entrada,
        e.id_producto,
        p.codigo   AS codigo_producto,
        p.nombre   AS nombre_producto,
        COALESCE(c.nombre, '') AS nombre_categoria,
        e.fecha_entrada,
        e.cantidad,
        e.precio_unitario,
        e.observaciones,
        e.usuario_registro
      FROM entradas_productos e
      JOIN productos  p ON p.id_producto  = e.id_producto
      LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
      ORDER BY e.fecha_entrada DESC, e.id_entrada DESC
    ''');
  }

  Future<int> registrar(Map<String, dynamic> body) async {
    final db = await _db;
    return db.transaction<int>((tx) async {
      final idProducto = body['id_producto'] as int;
      final cantidad   = body['cantidad'] as int;

      final id = await tx.insert('entradas_productos', {
        'id_producto':      idProducto,
        'fecha_entrada':    body['fecha_entrada'], // 'YYYY-MM-DD'
        'cantidad':         cantidad,
        'precio_unitario':  body['precio_unitario'], // puede ser null
        'observaciones':    (body['observaciones']    ?? '') as String,
        'usuario_registro': (body['usuario_registro'] ?? 'sistema') as String,
      });

      // Sumar stock (era trigger en Postgres, acá lo hacemos manualmente)
      await tx.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual + ? WHERE id_producto = ?',
        [cantidad, idProducto],
      );

      return id;
    });
  }

  Future<void> eliminar(int idEntrada) async {
    final db = await _db;
    await db.transaction((tx) async {
      // Leer la entrada primero para revertir stock
      final rows = await tx.query('entradas_productos',
          where: 'id_entrada = ?', whereArgs: [idEntrada], limit: 1);
      if (rows.isEmpty) return;
      final e = rows.first;
      final idProducto = e['id_producto'] as int;
      final cantidad   = e['cantidad']    as int;

      await tx.delete('entradas_productos',
          where: 'id_entrada = ?', whereArgs: [idEntrada]);

      // Revertir stock (restar lo que se había sumado)
      await tx.rawUpdate(
        'UPDATE productos SET stock_actual = stock_actual - ? WHERE id_producto = ?',
        [cantidad, idProducto],
      );
    });
  }

  // Helper para producir la fecha string desde DateTime
  static String hoy() => dateOnly(DateTime.now());
}
