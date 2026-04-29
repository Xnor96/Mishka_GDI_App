import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/entrada_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class EntradasState {
  final List<Entrada> entradas;
  final bool          isLoading;
  final String?       error;
  final bool          guardando;   // true mientras se hace POST

  const EntradasState({
    this.entradas  = const [],
    this.isLoading = false,
    this.error,
    this.guardando = false,
  });

  EntradasState copyWith({
    List<Entrada>? entradas,
    bool?          isLoading,
    String?        error,
    bool?          guardando,
    bool           clearError = false,
  }) => EntradasState(
    entradas:  entradas  ?? this.entradas,
    isLoading: isLoading ?? this.isLoading,
    error:     clearError ? null : (error ?? this.error),
    guardando: guardando ?? this.guardando,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class EntradasNotifier extends StateNotifier<EntradasState> {
  EntradasNotifier() : super(const EntradasState());

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await ApiClient.instance.get('/api/entradas');
      final list = (res.data['data'] as List)
          .map((j) => Entrada.fromJson(j as Map<String, dynamic>))
          .toList();
      // Más recientes primero
      list.sort((a, b) => b.fechaEntrada.compareTo(a.fechaEntrada));
      state = state.copyWith(entradas: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> registrar(Map<String, dynamic> body) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await ApiClient.instance.post('/api/entradas', data: body);
      state = state.copyWith(guardando: false);
      await cargar(); // refresca la lista
      return true;
    } catch (e) {
      state = state.copyWith(guardando: false, error: e.toString());
      return false;
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      await ApiClient.instance.delete('/api/entradas/$id');
      // Quita el item de la lista local inmediatamente
      state = state.copyWith(
        entradas: state.entradas.where((e) => e.id != id).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void limpiarError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final entradasProvider =
    StateNotifierProvider<EntradasNotifier, EntradasState>(
      (_) => EntradasNotifier(),
    );
