import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// DAO de productos. Devuelve Map<String,dynamic> con la misma forma que
/// espera Producto.fromJson (id_producto, codigo, nombre, id_categoria,
/// unidad_medida, precio_unitario, stock_actual, stock_inicial).
class ProductoDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  Future<List<Map<String, dynamic>>> listar() async {
    final db = await _db;
    return db.query('productos', orderBy: 'nombre COLLATE NOCASE ASC');
  }

  Future<Map<String, dynamic>?> porId(int id) async {
    final db = await _db;
    final rows = await db.query('productos',
        where: 'id_producto = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Búsqueda por código o nombre (case-insensitive).
  Future<List<Map<String, dynamic>>> buscar(String q) async {
    final db = await _db;
    final like = '%${q.toLowerCase()}%';
    return db.rawQuery(
      '''
      SELECT * FROM productos
       WHERE lower(codigo) LIKE ? OR lower(nombre) LIKE ?
       ORDER BY nombre COLLATE NOCASE ASC
      ''',
      [like, like],
    );
  }

  /// Filtra por categoría (usado por búsqueda + filtro combinados).
  Future<List<Map<String, dynamic>>> porCategoria(int idCategoria) async {
    final db = await _db;
    return db.query('productos',
        where: 'id_categoria = ?',
        whereArgs: [idCategoria],
        orderBy: 'nombre COLLATE NOCASE ASC');
  }

  Future<int> crear(Map<String, dynamic> body) async {
    final db = await _db;
    return db.insert('productos', {
      'codigo':          body['codigo'],
      'nombre':          body['nombre'],
      'id_categoria':    body['id_categoria'],
      'unidad_medida':   body['unidad_medida']    ?? 'UNIDAD',
      'precio_unitario': (body['precio_unitario'] ?? 0).toDouble(),
      'stock_actual':    body['stock_actual']     ?? 0,
      'stock_inicial':   body['stock_inicial']    ?? body['stock_actual'] ?? 0,
    });
  }

  Future<void> actualizar(int id, Map<String, dynamic> body) async {
    final db = await _db;
    final payload = <String, dynamic>{};
    for (final k in const [
      'codigo', 'nombre', 'id_categoria', 'unidad_medida',
      'precio_unitario', 'stock_actual', 'stock_inicial',
    ]) {
      if (body.containsKey(k)) payload[k] = body[k];
    }
    if (payload.isEmpty) return;
    // Forzar update de fecha_actualizacion (por si el trigger tarda)
    await db.update('productos', payload,
        where: 'id_producto = ?', whereArgs: [id]);
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('productos', where: 'id_producto = ?', whereArgs: [id]);
  }

  /// Ajusta stock del producto (positivo = suma, negativo = resta).
  /// Usado por EntradaDao/SalidaDao dentro de transacciones.
  Future<void> ajustarStock(DatabaseExecutor tx, int idProducto, int delta) async {
    await tx.rawUpdate(
      'UPDATE productos SET stock_actual = stock_actual + ? WHERE id_producto = ?',
      [delta, idProducto],
    );
  }

  /// Top N productos más vendidos en los últimos días (default: 60 días).
  /// Solo retorna productos CON stock > 0 (si no, no se pueden volver a vender).
  /// Ordenados por frecuencia de venta descendente.
  Future<List<Map<String, dynamic>>> recientesVendidos({
    int limite = 8,
    int ultimosDias = 60,
  }) async {
    final db = await _db;
    final desde = DateTime.now().subtract(Duration(days: ultimosDias));
    final desdeStr = '${desde.year.toString().padLeft(4, '0')}-'
        '${desde.month.toString().padLeft(2, '0')}-'
        '${desde.day.toString().padLeft(2, '0')}';
    return db.rawQuery('''
      SELECT p.*
      FROM productos p
      JOIN (
        SELECT id_producto, COUNT(*) AS veces, MAX(fecha_salida) AS ult
        FROM salidas_productos
        WHERE fecha_salida >= ?
        GROUP BY id_producto
      ) s ON s.id_producto = p.id_producto
      WHERE p.stock_actual > 0
      ORDER BY s.veces DESC, s.ult DESC
      LIMIT ?
    ''', [desdeStr, limite]);
  }
}
