import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/dao/auth_dao.dart';

// ── Estado del login ──────────────────────────────────────────────
enum AuthStatus { idle, loading, success, error }

class AuthState {
  final AuthStatus status;
  final String?    errorMessage;
  final String?    username;
  final String?    rol;

  const AuthState({
    this.status = AuthStatus.idle,
    this.errorMessage,
    this.username,
    this.rol,
  });

  AuthState copyWith({
    AuthStatus? status,
    String?     errorMessage,
    String?     username,
    String?     rol,
  }) => AuthState(
    status:       status       ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    username:     username     ?? this.username,
    rol:          rol          ?? this.rol,
  );
}

// ── Notifier (sin backend, sin JWT) ───────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  final _dao = AuthDao();

  Future<bool> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final result = await _dao.login(username, password);
      if (!result.ok) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: result.error ?? 'Error al iniciar sesión',
        );
        return false;
      }

      // La "sesión" es simplemente el username + rol persistidos.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyUsername, result.username);
      await prefs.setString(AppConstants.keyRol,      result.rol);

      state = state.copyWith(
        status:   AuthStatus.success,
        username: result.username,
        rol:      result.rol,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Error inesperado: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyUsername);
    await prefs.remove(AppConstants.keyRol);
    state = const AuthState();
  }

  void resetError() => state = state.copyWith(
    status: AuthStatus.idle,
    errorMessage: null,
  );
}

// ── Providers ─────────────────────────────────────────────────────
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
