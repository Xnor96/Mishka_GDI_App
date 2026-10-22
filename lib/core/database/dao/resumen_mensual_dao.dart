import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';
import 'dao_helpers.dart';

/// DAO del resumen mensual (upsert por mes/año).
/// Retorna maps con la forma que espera ResumenMensual.fromJson, incluido
/// nombre_mes que no está en la tabla (se calcula).
class ResumenMensualDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  Future<Map<String, dynamic>?> porMesAnio(int mes, int anio) async {
    final db = await _db;
    final rows = await db.query('resumen_mensual',
        where: 'mes = ? AND anio = ?', whereArgs: [mes, anio], limit: 1);
    if (rows.isEmpty) return null;
    return _withNombre(rows.first);
  }

  Future<Map<String, dynamic>?> actual() async {
    final now = DateTime.now();
    return porMesAnio(now.month, now.year);
  }

  /// Upsert: si ya existe (mes, anio) se sobrescriben los montos.
  /// El campo `balance` es GENERATED STORED — se calcula solo.
  Future<Map<String, dynamic>> generar(Map<String, dynamic> body) async {
    final db = await _db;
    final mes  = body['mes']  as int;
    final anio = body['anio'] as int;

    // Si todos los montos son 0, calcular desde ventas + control_diario del mes
    final ingr = (body['total_ingresos']         ?? 0).toDouble();
    final gf   = (body['total_gastos_fijos']     ?? 0).toDouble();
    final gv   = (body['total_gastos_variables'] ?? 0).toDouble();

    late final double finIngr;
    late final double finGF;
    late final double finGV;

    if (ingr == 0 && gf == 0 && gv == 0) {
      // Auto-calcular
      final ventas = await db.rawQuery('''
        SELECT COALESCE(SUM(total), 0) AS t
          FROM salidas_productos
         WHERE strftime('%m', fecha_salida) = ? AND strftime('%Y', fecha_salida) = ?
      ''', [mes.toString().padLeft(2, '0'), anio.toString()]);
      final gastos = await db.rawQuery('''
        SELECT COALESCE(SUM(monto_salida), 0) AS t
          FROM control_diario
         WHERE strftime('%m', fecha) = ? AND strftime('%Y', fecha) = ?
      ''', [mes.toString().padLeft(2, '0'), anio.toString()]);
      finIngr = ((ventas.first['t'] as num?) ?? 0).toDouble();
      finGF   = 0;
      finGV   = ((gastos.first['t'] as num?) ?? 0).toDouble();
    } else {
      finIngr = ingr; finGF = gf; finGV = gv;
    }

    final payload = {
      'mes':                    mes,
      'anio':                   anio,
      'total_ingresos':         finIngr,
      'total_gastos_fijos':     finGF,
      'total_gastos_variables': finGV,
      'observaciones':          (body['observaciones'] ?? '') as String,
      'fecha_generacion':       DateTime.now().toIso8601String(),
    };

    // Intentar update primero; si no afectó filas, insertar
    final upd = await db.update('resumen_mensual', payload,
        where: 'mes = ? AND anio = ?', whereArgs: [mes, anio]);
    if (upd == 0) {
      await db.insert('resumen_mensual', payload);
    }

    return (await porMesAnio(mes, anio))!;
  }

  Map<String, dynamic> _withNombre(Map<String, dynamic> row) {
    final out = Map<String, dynamic>.from(row);
    final mes = out['mes'] as int;
    out['nombre_mes'] = (mes >= 1 && mes <= 12) ? mesesEs[mes] : '';
    return out;
  }
}
