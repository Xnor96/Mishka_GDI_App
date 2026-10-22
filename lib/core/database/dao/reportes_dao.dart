import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Consultas agregadas de la pantalla Reportes.
class ReportesDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  /// Inventario valorado: cada producto con stock * precio.
  Future<List<Map<String, dynamic>>> inventarioActual() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT p.id_producto,
             p.codigo,
             p.nombre,
             COALESCE(c.nombre, '') AS categoria,
             p.unidad_medida,
             p.precio_unitario,
             p.stock_actual,
             (p.stock_actual * p.precio_unitario) AS valor_total
        FROM productos p
        LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
       ORDER BY p.nombre COLLATE NOCASE ASC
    ''');
  }

  /// Movimientos (entradas + salidas) entre dos fechas inclusive.
  Future<List<Map<String, dynamic>>> movimientos(String inicio, String fin) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT fecha_entrada AS fecha,
             'ENTRADA'     AS tipo,
             p.codigo,
             p.nombre,
             COALESCE(c.nombre, '') AS categoria,
             e.cantidad,
             COALESCE(e.precio_unitario, 0)               AS precio,
             (e.cantidad * COALESCE(e.precio_unitario,0)) AS total,
             ''                                            AS lugar_venta,
             ''                                            AS tipo_pago
        FROM entradas_productos e
        JOIN productos  p ON p.id_producto  = e.id_producto
        LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
       WHERE e.fecha_entrada BETWEEN ? AND ?
      UNION ALL
      SELECT s.fecha_salida  AS fecha,
             'SALIDA'         AS tipo,
             p.codigo,
             p.nombre,
             COALESCE(c.nombre, '') AS categoria,
             s.cantidad,
             s.precio_venta   AS precio,
             s.total          AS total,
             s.lugar_venta,
             s.tipo_pago
        FROM salidas_productos s
        JOIN productos  p ON p.id_producto  = s.id_producto
        LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
       WHERE s.fecha_salida BETWEEN ? AND ?
       ORDER BY fecha DESC
    ''', [inicio, fin, inicio, fin]);
  }

  /// Top productos más vendidos (por cantidad vendida).
  Future<List<Map<String, dynamic>>> masVendidos({int limite = 20}) async {
    final db = await _db;
    return db.rawQuery('''
      SELECT p.id_producto,
             p.codigo,
             p.nombre,
             COALESCE(c.nombre, '') AS categoria,
             COALESCE(SUM(s.cantidad), 0)  AS total_vendido,
             COALESCE(SUM(s.total),    0)  AS total_ingresos
        FROM salidas_productos s
        JOIN productos  p ON p.id_producto  = s.id_producto
        LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
       GROUP BY p.id_producto, p.codigo, p.nombre, c.nombre
       ORDER BY total_vendido DESC
       LIMIT ?
    ''', [limite]);
  }

  /// Valoración por categoría (mismo shape que Dashboard.valoracionPorCategoria
  /// pero como método independiente para el tab de Reportes).
  Future<List<Map<String, dynamic>>> valoracion() async {
    final db = await _db;
    return db.rawQuery('''
      SELECT c.id_categoria,
             c.nombre                                                        AS nombre_categoria,
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
