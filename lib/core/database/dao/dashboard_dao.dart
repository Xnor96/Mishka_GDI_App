import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'dao_helpers.dart';

/// Consultas agregadas del Dashboard. Cada método devuelve rows con la forma
/// exacta que esperan los `fromJson` de dashboard_models.dart.
class DashboardDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  /// AlertaStockBajo: stock_actual <= 3 (incluye 0).
  Future<List<Map<String, dynamic>>> alertasStockBajo() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT p.id_producto,
             p.codigo,
             p.nombre,
             COALESCE(c.nombre, '') AS categoria,
             p.stock_actual,
             p.stock_inicial,
             p.precio_unitario
        FROM productos p
        LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
       WHERE p.stock_actual <= 3
       ORDER BY p.stock_actual ASC, p.nombre COLLATE NOCASE ASC
    ''');
  }

  /// Control diario de hoy: registros del día + totales.
  Future<Map<String, dynamic>> controlHoy() async {
    final db = await _db;
    final hoyStr = dateOnly(DateTime.now());
    final registros = await db.query('control_diario',
        where: 'fecha = ?', whereArgs: [hoyStr],
        orderBy: 'id_control DESC');
    // Normalizar es_verbena → bool para el dashboard model
    final list = registros.map((r) {
      final m = Map<String, dynamic>.from(r);
      final v = m['es_verbena'];
      if (v is int) m['es_verbena'] = v != 0;
      return m;
    }).toList();
    final tot = await db.rawQuery('''
      SELECT COALESCE(SUM(monto_entrada), 0) AS te,
             COALESCE(SUM(monto_salida),  0) AS ts
        FROM control_diario WHERE fecha = ?
    ''', [hoyStr]);
    return {
      'data':          list,
      'total_entrada': ((tot.first['te'] as num?) ?? 0).toDouble(),
      'total_salida':  ((tot.first['ts'] as num?) ?? 0).toDouble(),
    };
  }

  /// Valoración de inventario agregada por categoría.
  Future<List<Map<String, dynamic>>> valoracionPorCategoria() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT c.id_categoria,
             c.nombre AS nombre_categoria,
             COUNT(p.id_producto)                                            AS total_productos,
             COALESCE(SUM(p.stock_actual), 0)                                AS total_unidades,
             COALESCE(SUM(p.stock_actual * p.precio_unitario), 0)            AS valor_total
        FROM categorias c
        LEFT JOIN productos p ON p.id_categoria = c.id_categoria
       GROUP BY c.id_categoria, c.nombre
       ORDER BY c.nombre ASC
    ''');
  }
}
