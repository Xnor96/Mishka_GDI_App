import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/app_constants.dart';
import '../models/auth_models.dart';

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

// ── Notifier ──────────────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _dio = ApiClient().dio;

  Future<bool> login(String username, String password) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final response = await _dio.post('/api/auth/login', data: {
        'username': username,
        'password': password,
      });

      final auth = AuthResponse.fromJson(response.data);

      if (!auth.success || auth.accessToken.isEmpty) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: auth.message.isNotEmpty ? auth.message : 'Error al iniciar sesión',
        );
        return false;
      }

      // Guardar en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.keyAccessToken,  auth.accessToken);
      await prefs.setString(AppConstants.keyRefreshToken, auth.refreshToken);
      await prefs.setString(AppConstants.keyUsername,     auth.username);
      await prefs.setString(AppConstants.keyRol,          auth.rol);

      state = state.copyWith(
        status:   AuthStatus.success,
        username: auth.username,
        rol:      auth.rol,
      );
      return true;

    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ??
                  e.response?.data?['message'] ??
                  'No se pudo conectar al servidor';
      state = state.copyWith(status: AuthStatus.error, errorMessage: msg);
      return false;
    } catch (_) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Error inesperado. Intenta de nuevo.',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/auth/logout');
    } catch (_) {
      // Stateless: aunque falle, limpiamos localmente
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyRefreshToken);
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
