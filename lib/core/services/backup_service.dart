import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/database_helper.dart';

/// Copia el archivo mishka.db a una carpeta interna de backups con timestamp.
/// Rota: solo mantiene las últimas [_maxBackups] copias.
///
/// - `backup()` — copia silenciosa (usado al cerrar la app).
/// - `compartirUltimoBackup()` — comparte la copia más reciente por el
///   share sheet nativo (Drive, Correo, USB, etc.).
class BackupService {
  static const _maxBackups = 7;
  static const _folderName = 'mishka_backups';

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir  = Directory(p.join(docs.path, _folderName));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  /// Copia mishka.db a mishka_backups/mishka_YYYYMMDD_HHMMSS.db.
  /// Devuelve el File del backup creado (o null si no había BD).
  Future<File?> backup() async {
    final dbPath = await DatabaseHelper.instance.dbPath;
    final src    = File(dbPath);
    if (!src.existsSync()) return null;

    final dir = await _backupDir();
    final now = DateTime.now();
    final stamp = '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
    final dest = File(p.join(dir.path, 'mishka_$stamp.db'));
    await src.copy(dest.path);

    await _rotar(dir);
    return dest;
  }

  /// Comparte el backup más reciente (o genera uno nuevo si no hay ninguno).
  Future<void> compartirUltimoBackup() async {
    var files = await _listarBackups();
    if (files.isEmpty) {
      final nuevo = await backup();
      if (nuevo == null) return;
      files = [nuevo];
    }
    final latest = files.first;
    await Share.shareXFiles(
      [XFile(latest.path)],
      subject: 'Backup Mishka GDI',
      text:    'Respaldo de la base de datos de Mishka GDI.',
    );
  }

  /// Lista los backups ordenados de más reciente a más viejo.
  Future<List<File>> _listarBackups() async {
    final dir = await _backupDir();
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => p.basename(f.path).startsWith('mishka_') &&
            f.path.endsWith('.db'))
        .toList();
    // Nombre incluye timestamp, así que ordenar desc por nombre es correcto
    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
    return files;
  }

  /// Elimina los backups sobrantes, dejando solo los últimos [_maxBackups].
  Future<void> _rotar(Directory _) async {
    final files = await _listarBackups();
    if (files.length <= _maxBackups) return;
    for (final f in files.skip(_maxBackups)) {
      try {
        await f.delete();
      } catch (_) {
        // Ignoramos errores de borrado — no es crítico
      }
    }
  }
}
