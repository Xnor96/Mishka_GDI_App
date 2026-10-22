import 'package:bcrypt/bcrypt.dart';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// Resultado de un intento de login local.
class AuthLocalResult {
  final bool ok;
  final String username;
  final String rol;
  final String? error;

  const AuthLocalResult({
    required this.ok,
    this.username = '',
    this.rol = '',
    this.error,
  });
}

/// DAO de autenticación local. Verifica el password contra el hash bcrypt
/// guardado en la tabla `usuarios`. Sin JWT ni tokens.
class AuthDao {
  Future<Database> get _db async => await DatabaseHelper.instance.db;

  Future<AuthLocalResult> login(String username, String password) async {
    final db = await _db;
    final rows = await db.query('usuarios',
        where: 'username = ? AND activo = 1',
        whereArgs: [username.trim()],
        limit: 1);
    if (rows.isEmpty) {
      return const AuthLocalResult(ok: false, error: 'Usuario o contraseña incorrectos');
    }
    final r = rows.first;
    final hash = r['password_hash'] as String;
    final ok = BCrypt.checkpw(password, hash);
    if (!ok) {
      return const AuthLocalResult(ok: false, error: 'Usuario o contraseña incorrectos');
    }
    return AuthLocalResult(
      ok: true,
      username: r['username'] as String,
      rol:      r['rol']      as String,
    );
  }
}
