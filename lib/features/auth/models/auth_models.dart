/// Estado de un intento de login local.
/// Ya no hay tokens JWT — el login se resuelve consultando la tabla
/// `usuarios` de SQLite y verificando el hash bcrypt del password.
class AuthResponse {
  final bool   success;
  final String message;
  final String username;
  final String rol;

  AuthResponse({
    required this.success,
    required this.message,
    required this.username,
    required this.rol,
  });
}
