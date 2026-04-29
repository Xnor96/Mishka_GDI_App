import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/salida_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SalidasState {
  final List<Salida> salidas;
  final bool         isLoading;
  final String?      error;
  final bool         guardando;

  const SalidasState({
    this.salidas   = const [],
    this.isLoading = false,
    this.error,
    this.guardando = false,
  });

  SalidasState copyWith({
    List<Salida>? salidas,
    bool?         isLoading,
    String?       error,
    bool?         guardando,
    bool          clearError = false,
  }) => SalidasState(
    salidas:   salidas   ?? this.salidas,
    isLoading: isLoading ?? this.isLoading,
    error:     clearError ? null : (error ?? this.error),
    guardando: guardando ?? this.guardando,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class SalidasNotifier extends StateNotifier<SalidasState> {
  SalidasNotifier() : super(const SalidasState());

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await ApiClient.instance.get('/api/salidas');
      final list = (res.data['data'] as List)
          .map((j) => Salida.fromJson(j as Map<String, dynamic>))
          .toList();
      // Más recientes primero
      list.sort((a, b) => b.fechaSalida.compareTo(a.fechaSalida));
      state = state.copyWith(salidas: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> registrar(Map<String, dynamic> body) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await ApiClient.instance.post('/api/salidas', data: body);
      state = state.copyWith(guardando: false);
      await cargar(); // refresca lista
      return true;
    } catch (e) {
      state = state.copyWith(guardando: false, error: e.toString());
      return false;
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      await ApiClient.instance.delete('/api/salidas/$id');
      state = state.copyWith(
        salidas: state.salidas.where((s) => s.id != id).toList(),
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

final salidasProvider =
    StateNotifierProvider<SalidasNotifier, SalidasState>(
      (_) => SalidasNotifier(),
    );
