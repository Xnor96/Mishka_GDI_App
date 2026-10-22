import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

class CategoriaDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  Future<List<Map<String, dynamic>>> listar() async {
    final db = await _db;
    return db.query('categorias', orderBy: 'nombre ASC');
  }

  /// Mapa id → nombre para joins in-memory (evitar JOINs SQL cuando alcanza).
  Future<Map<int, String>> mapa() async {
    final rows = await listar();
    return {
      for (final r in rows) r['id_categoria'] as int: r['nombre'] as String,
    };
  }
}
