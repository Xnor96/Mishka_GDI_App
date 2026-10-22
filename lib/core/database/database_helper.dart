import 'dart:async';
import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Singleton que administra la conexión SQLite del GDI.
///
/// - En el primer arranque intenta copiar el seed (`assets/db/mishka_seed.db`)
///   desde los assets al directorio de documentos de la app. Si el seed no
///   existe (dev fresh install), crea una BD vacía aplicando el DDL desde
///   `assets/db/ddl.sql` e inserta las 6 categorías y un usuario admin
///   por defecto.
/// - Activa `foreign_keys = ON` y modo WAL en cada apertura.
/// - Expone `db` para uso de los DAOs.
class DatabaseHelper {
  static const _dbFileName   = 'mishka.db';
  static const _seedAsset    = 'assets/db/mishka_seed.db';
  static const _ddlAsset     = 'assets/db/ddl.sql';
  static const _schemaVersion = 2;

  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  /// Ruta absoluta al archivo mishka.db en documentos del usuario.
  /// Se usa para el feature de backup automático.
  Future<String> get dbPath async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  Future<Database> _open() async {
    final path = await dbPath;
    final exists = File(path).existsSync();

    if (!exists) {
      await _bootstrap(path);
    }

    final database = await openDatabase(
      path,
      version: _schemaVersion,
      onConfigure: (db) async {
        // foreign_keys = ON no devuelve filas → execute funciona.
        await db.execute('PRAGMA foreign_keys = ON');
        // journal_mode SÍ devuelve una fila (el modo activo tras el cambio)
        // → hay que usar rawQuery, no execute, si no sqflite en Android tira
        //   "Queries can be performed using ... query or rawQuery methods only."
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onUpgrade: (db, oldV, newV) async {
        if (oldV < 2) {
          await _migrateV1toV2(db);
        }
        // Reservado para migraciones futuras (v3, etc.)
      },
    );

    return database;
  }

  /// Primer arranque: intenta copiar el seed. Si no está, aplica DDL vacío.
  Future<void> _bootstrap(String dbPath) async {
    // Asegurar carpeta padre
    final dir = Directory(p.dirname(dbPath));
    if (!dir.existsSync()) dir.createSync(recursive: true);

    // Intento 1: copiar mishka_seed.db (BD con datos migrados de Postgres)
    try {
      final seed = await rootBundle.load(_seedAsset);
      final bytes = seed.buffer.asUint8List(seed.offsetInBytes, seed.lengthInBytes);
      // Solo consideramos que el seed es válido si pesa > 8 KB (SQLite header + tablas)
      if (bytes.length > 8 * 1024) {
        await File(dbPath).writeAsBytes(bytes, flush: true);
        return;
      }
    } catch (_) {
      // Seed no existe o está vacío → fallback al DDL desde cero
    }

    // Intento 2: DDL desde cero + admin default
    final ddl = await rootBundle.loadString(_ddlAsset);
    final tmp = await openDatabase(dbPath, version: _schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
    );
    // executeScript no existe en sqflite; separar por ';' respetando strings
    for (final stmt in _splitSqlStatements(ddl)) {
      final s = stmt.trim();
      if (s.isEmpty) continue;
      await tmp.execute(s);
    }

    // Semilla mínima: 6 categorías + usuario admin (password bcrypt 'admin123')
    await _seedMinimal(tmp);
    await tmp.close();
  }

  Future<void> _seedMinimal(Database db) async {
    // Categorías canónicas del Excel original
    const categorias = ['ANILLO', 'ARETE', 'COLLAR', 'JUEGO', 'OTRO', 'PULSERA'];
    for (final nombre in categorias) {
      await db.insert('categorias', {'nombre': nombre},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Admin default
    final hash = BCrypt.hashpw('admin123', BCrypt.gensalt());
    await db.insert('usuarios', {
      'username':      'admin',
      'email':         'admin@mishka.local',
      'password_hash': hash,
      'nombre':        'Administrador',
      'rol':           'admin',
      'activo':        1,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Migración de v1 → v2: ventas multi-ítem (octubre 2026).
  /// Crea la tabla `ventas` + columna `id_venta` en `salidas_productos` +
  /// convierte cada salida existente en su propia venta de 1 línea.
  Future<void> _migrateV1toV2(Database db) async {
    // 1. Tabla ventas
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ventas (
          id_venta            INTEGER PRIMARY KEY AUTOINCREMENT,
          fecha_venta         DATE     NOT NULL,
          lugar_venta         TEXT     NOT NULL DEFAULT '',
          tipo_pago           TEXT     NOT NULL DEFAULT '',
          total               REAL     NOT NULL DEFAULT 0.0,
          observaciones       TEXT     NOT NULL DEFAULT '',
          usuario_registro    TEXT     NOT NULL DEFAULT 'sistema',
          fecha_creacion      DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          fecha_actualizacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
          CHECK (total >= 0)
      )
    ''');

    // 2. Agregar columna id_venta a salidas_productos si no existe.
    //    (SQLite no permite REFERENCES en ADD COLUMN; se registra como
    //    INTEGER plano. La relación lógica la mantenemos a mano.)
    final cols = await db.rawQuery("PRAGMA table_info(salidas_productos)");
    final hasIdVenta = cols.any((c) => c['name'] == 'id_venta');
    if (!hasIdVenta) {
      await db.execute(
          'ALTER TABLE salidas_productos ADD COLUMN id_venta INTEGER');
    }

    // 3. Índices + trigger de fecha_actualizacion
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_salidas_venta ON salidas_productos(id_venta)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ventas_fecha ON ventas(fecha_venta)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_ventas_lugar ON ventas(lugar_venta)');
    await db.execute('''
      CREATE TRIGGER IF NOT EXISTS trg_ventas_fecha
      AFTER UPDATE ON ventas FOR EACH ROW
      WHEN NEW.fecha_actualizacion IS OLD.fecha_actualizacion
      BEGIN
          UPDATE ventas SET fecha_actualizacion = CURRENT_TIMESTAMP WHERE id_venta = NEW.id_venta;
      END
    ''');

    // 4. Migración de datos: por cada salida sin id_venta, crear una venta
    //    espejo (misma fecha/lugar/pago/total) y asignarle id_venta.
    final salidas = await db.query('salidas_productos',
        where: 'id_venta IS NULL', orderBy: 'id_salida ASC');
    for (final s in salidas) {
      final idVenta = await db.insert('ventas', {
        'fecha_venta':         s['fecha_salida'],
        'lugar_venta':         s['lugar_venta'] ?? '',
        'tipo_pago':           s['tipo_pago']   ?? '',
        'total':               s['total']       ?? 0.0,
        'observaciones':       s['observaciones']    ?? '',
        'usuario_registro':    s['usuario_registro'] ?? 'sistema',
        'fecha_creacion':      s['fecha_creacion'],
        'fecha_actualizacion': s['fecha_actualizacion'],
      });
      await db.update('salidas_productos', {'id_venta': idVenta},
          where: 'id_salida = ?', whereArgs: [s['id_salida']]);
    }
  }

  /// Split ingenuo por `;` que evita cortar dentro de bloques BEGIN...END
  /// (usados en triggers).
  List<String> _splitSqlStatements(String script) {
    final out = <String>[];
    final buf = StringBuffer();
    var depth = 0; // profundidad de BEGIN..END
    for (final line in script.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('--')) continue;
      buf.writeln(trimmed);
      final upper = trimmed.toUpperCase();
      if (upper.contains('BEGIN')) depth++;
      if (upper.contains('END;'))  depth--;
      if (trimmed.endsWith(';') && depth <= 0) {
        out.add(buf.toString());
        buf.clear();
        depth = 0;
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }
}
