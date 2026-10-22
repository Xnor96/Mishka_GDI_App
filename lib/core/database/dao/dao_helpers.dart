/// Utilidades comunes para todos los DAOs.
///
/// SQLite guarda booleanos como INTEGER (0/1) y timestamps como TEXT ISO-8601
/// (o UNIX epoch en algunos casos). Las factories `fromJson` de los modelos
/// esperan `bool` y `String` parseable con DateTime.parse.
/// Estos helpers hacen la traducción.

Map<String, dynamic> normalize(Map<String, dynamic> row, {
  Set<String> boolFields = const {},
}) {
  final out = Map<String, dynamic>.from(row);
  for (final k in boolFields) {
    final v = out[k];
    if (v is int) out[k] = v != 0;
  }
  return out;
}

/// Convierte una fecha (String ISO o DateTime) a "YYYY-MM-DD" para columnas DATE.
String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Meses en español (para ResumenMensual.nombre_mes que no está en la tabla).
const List<String> mesesEs = [
  '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
