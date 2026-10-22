import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'dao_helpers.dart';

/// DAO de control diario (ingresos/gastos por día).
/// El provider espera:
///   - listar() → List de rows normalizados
///   - registrar(body) → int id
///   - eliminar(id)
///   - generarDesdeVentas(fechaStr) → suma total de ventas del día y crea
///     un movimiento de "corte de ventas" en Control Diario
class ControlDiarioDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  static const _boolFields = {'es_verbena'};

  Future<List<Map<String, dynamic>>> listar({
    bool soloHoy    = false,
    bool soloVerbena = false,
  }) async {
    final db = await _db;
    final wheres = <String>[];
    final args   = <Object?>[];
    if (soloHoy) {
      wheres.add('fecha = ?');
      args.add(dateOnly(DateTime.now()));
    }
    if (soloVerbena) {
      wheres.add('es_verbena = 1');
    }
    final where = wheres.isEmpty ? null : wheres.join(' AND ');
    final rows = await db.query('control_diario',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'fecha DESC, id_control DESC');
    return rows.map((r) => normalize(r, boolFields: _boolFields)).toList();
  }

  Future<int> registrar(Map<String, dynamic> body) async {
    final db = await _db;
    return db.insert('control_diario', {
      'fecha':            body['fecha'],
      'descripcion':      body['descripcion'],
      'monto_entrada':    (body['monto_entrada']  ?? 0).toDouble(),
      'monto_salida':     (body['monto_salida']   ?? 0).toDouble(),
      'observaciones':    (body['observaciones']  ?? '') as String,
      'es_verbena':       (body['es_verbena'] == true) ? 1 : 0,
      'usuario_registro': (body['usuario_registro'] ?? 'sistema') as String,
    });
  }

  Future<void> eliminar(int id) async {
    final db = await _db;
    await db.delete('control_diario',
        where: 'id_control = ?', whereArgs: [id]);
  }

  /// Suma el total de ventas del día indicado y crea un movimiento en control
  /// diario con descripción "Corte de ventas del día".
  Future<int?> generarDesdeVentas(String fechaStr,
      {String usuario = 'sistema'}) async {
    final db = await _db;
    return db.transaction<int?>((tx) async {
      final s = await tx.rawQuery(
        'SELECT COALESCE(SUM(total), 0) AS total FROM salidas_productos WHERE fecha_salida = ?',
        [fechaStr],
      );
      final total = ((s.first['total'] as num?) ?? 0).toDouble();
      if (total <= 0) return null;
      return tx.insert('control_diario', {
        'fecha':            fechaStr,
        'descripcion':      'Corte de ventas del día',
        'monto_entrada':    total,
        'monto_salida':     0.0,
        'observaciones':    '',
        'es_verbena':       0,
        'usuario_registro': usuario,
      });
    });
  }

  /// Totales agregados (para los banners de la pantalla y el dashboard).
  Future<Map<String, double>> totales({
    bool soloHoy = false,
    bool soloVerbena = false,
  }) async {
    final db = await _db;
    final wheres = <String>[];
    final args   = <Object?>[];
    if (soloHoy) {
      wheres.add('fecha = ?');
      args.add(dateOnly(DateTime.now()));
    }
    if (soloVerbena) {
      wheres.add('es_verbena = 1');
    }
    final where = wheres.isEmpty ? '' : 'WHERE ${wheres.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(monto_entrada), 0) AS te,
             COALESCE(SUM(monto_salida),  0) AS ts
        FROM control_diario $where
    ''', args);
    final te = ((rows.first['te'] as num?) ?? 0).toDouble();
    final ts = ((rows.first['ts'] as num?) ?? 0).toDouble();
    return {'te': te, 'ts': ts, 'balance': te - ts};
  }
}
