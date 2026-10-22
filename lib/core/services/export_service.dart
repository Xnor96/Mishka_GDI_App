import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

/// Genera un .xlsx con 5 hojas (Productos, Entradas, Salidas, Control Diario,
/// Resumen Mensual) leyendo directo de la BD SQLite. Devuelve el archivo
/// listo para compartir con `share_plus`.
class ExportService {
  Future<File> exportarTodoAExcel() async {
    final db = await DatabaseHelper.instance.db;

    final excel = Excel.createExcel();
    // Excel siempre crea "Sheet1" — la eliminamos al final si sobra
    const defaultSheet = 'Sheet1';

    // ── Productos ────────────────────────────────────────────────
    {
      final rows = await db.rawQuery('''
        SELECT p.codigo, p.nombre, COALESCE(c.nombre, '') AS categoria,
               p.unidad_medida, p.precio_unitario, p.stock_actual, p.stock_inicial
          FROM productos p
          LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
         ORDER BY p.nombre COLLATE NOCASE ASC
      ''');
      final sheet = excel['Productos'];
      _writeHeader(sheet, [
        'Código', 'Nombre', 'Categoría', 'Unidad',
        'Precio', 'Stock actual', 'Stock inicial',
      ]);
      for (final r in rows) {
        sheet.appendRow([
          TextCellValue(r['codigo']         as String),
          TextCellValue(r['nombre']         as String),
          TextCellValue(r['categoria']      as String),
          TextCellValue(r['unidad_medida']  as String),
          DoubleCellValue((r['precio_unitario'] as num).toDouble()),
          IntCellValue(r['stock_actual']  as int),
          IntCellValue(r['stock_inicial'] as int),
        ]);
      }
    }

    // ── Entradas ─────────────────────────────────────────────────
    {
      final rows = await db.rawQuery('''
        SELECT e.fecha_entrada, p.codigo, p.nombre,
               COALESCE(c.nombre, '') AS categoria,
               e.cantidad, e.precio_unitario,
               e.observaciones, e.usuario_registro
          FROM entradas_productos e
          JOIN productos p ON p.id_producto = e.id_producto
          LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
         ORDER BY e.fecha_entrada DESC, e.id_entrada DESC
      ''');
      final sheet = excel['Entradas'];
      _writeHeader(sheet, [
        'Fecha', 'Código', 'Producto', 'Categoría',
        'Cantidad', 'Precio unitario', 'Observaciones', 'Usuario',
      ]);
      for (final r in rows) {
        sheet.appendRow([
          TextCellValue(r['fecha_entrada']  as String),
          TextCellValue(r['codigo']         as String),
          TextCellValue(r['nombre']         as String),
          TextCellValue(r['categoria']      as String),
          IntCellValue(r['cantidad']       as int),
          r['precio_unitario'] == null
              ? TextCellValue('')
              : DoubleCellValue((r['precio_unitario'] as num).toDouble()),
          TextCellValue(r['observaciones']    as String),
          TextCellValue(r['usuario_registro'] as String),
        ]);
      }
    }

    // ── Ventas (líneas) ──────────────────────────────────────────
    // Cada fila = una línea de venta. La columna "Venta #" agrupa las
    // líneas que pertenecen a la misma venta multi-ítem (ordenan juntas).
    {
      final rows = await db.rawQuery('''
        SELECT s.id_venta, s.fecha_salida, p.codigo, p.nombre,
               COALESCE(c.nombre, '') AS categoria,
               s.cantidad, s.precio_venta, s.total,
               s.lugar_venta, s.tipo_pago,
               s.observaciones, s.usuario_registro
          FROM salidas_productos s
          JOIN productos p ON p.id_producto = s.id_producto
          LEFT JOIN categorias c ON c.id_categoria = p.id_categoria
         ORDER BY s.fecha_salida DESC, s.id_venta DESC, s.id_salida ASC
      ''');
      final sheet = excel['Ventas'];
      _writeHeader(sheet, [
        'Venta #', 'Fecha', 'Código', 'Producto', 'Categoría',
        'Cantidad', 'Precio venta', 'Subtotal',
        'Lugar', 'Pago', 'Observaciones', 'Usuario',
      ]);
      for (final r in rows) {
        final idVenta = r['id_venta'];
        sheet.appendRow([
          idVenta == null
              ? TextCellValue('')
              : IntCellValue(idVenta as int),
          TextCellValue(r['fecha_salida']   as String),
          TextCellValue(r['codigo']         as String),
          TextCellValue(r['nombre']         as String),
          TextCellValue(r['categoria']      as String),
          IntCellValue(r['cantidad']       as int),
          DoubleCellValue((r['precio_venta'] as num).toDouble()),
          DoubleCellValue((r['total']        as num).toDouble()),
          TextCellValue(r['lugar_venta']      as String),
          TextCellValue(r['tipo_pago']        as String),
          TextCellValue(r['observaciones']    as String),
          TextCellValue(r['usuario_registro'] as String),
        ]);
      }
    }

    // ── Control Diario ───────────────────────────────────────────
    {
      final rows = await db.query('control_diario',
          orderBy: 'fecha DESC, id_control DESC');
      final sheet = excel['Control Diario'];
      _writeHeader(sheet, [
        'Fecha', 'Descripción', 'Monto entrada', 'Monto salida',
        'Balance', 'Verbena', 'Observaciones', 'Usuario',
      ]);
      for (final r in rows) {
        final me = (r['monto_entrada'] as num).toDouble();
        final ms = (r['monto_salida']  as num).toDouble();
        sheet.appendRow([
          TextCellValue(r['fecha']       as String),
          TextCellValue(r['descripcion'] as String),
          DoubleCellValue(me),
          DoubleCellValue(ms),
          DoubleCellValue(me - ms),
          TextCellValue((r['es_verbena'] as int) == 1 ? 'Sí' : 'No'),
          TextCellValue(r['observaciones']    as String),
          TextCellValue(r['usuario_registro'] as String),
        ]);
      }
    }

    // ── Resumen Mensual ──────────────────────────────────────────
    {
      final rows = await db.query('resumen_mensual',
          orderBy: 'anio DESC, mes DESC');
      final sheet = excel['Resumen Mensual'];
      _writeHeader(sheet, [
        'Mes', 'Año', 'Ingresos', 'Gastos fijos', 'Gastos variables',
        'Balance', 'Observaciones', 'Fecha generación',
      ]);
      for (final r in rows) {
        sheet.appendRow([
          IntCellValue(r['mes']  as int),
          IntCellValue(r['anio'] as int),
          DoubleCellValue((r['total_ingresos']         as num).toDouble()),
          DoubleCellValue((r['total_gastos_fijos']     as num).toDouble()),
          DoubleCellValue((r['total_gastos_variables'] as num).toDouble()),
          DoubleCellValue((r['balance']                as num).toDouble()),
          TextCellValue(r['observaciones']    as String),
          TextCellValue(r['fecha_generacion'] as String),
        ]);
      }
    }

    // Quitar la hoja default vacía si sigue ahí
    if (excel.sheets.containsKey(defaultSheet) &&
        excel.sheets[defaultSheet]!.maxRows == 0) {
      excel.delete(defaultSheet);
    }

    final bytes = excel.save();
    if (bytes == null) {
      throw StateError('No se pudo generar el Excel');
    }

    // Guardar en un directorio temporal — share_plus lo comparte por su URI
    final dir = await getTemporaryDirectory();
    final ts  = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final out = File(p.join(dir.path, 'mishka_export_$ts.xlsx'));
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }

  /// Genera el Excel y abre el share sheet nativo para que la usuaria
  /// elija destino (Drive, Correo, USB, WhatsApp, etc.).
  Future<void> compartirExcel() async {
    final file = await exportarTodoAExcel();
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Export Mishka GDI',
      text: 'Respaldo completo del inventario (Excel).',
    );
  }

  void _writeHeader(Sheet sheet, List<String> titles) {
    sheet.appendRow(titles.map<CellValue>((t) => TextCellValue(t)).toList());
    // Negrita en la primera fila
    for (var i = 0; i < titles.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(
        columnIndex: i,
        rowIndex: 0,
      ));
      cell.cellStyle = CellStyle(bold: true);
    }
  }
}
