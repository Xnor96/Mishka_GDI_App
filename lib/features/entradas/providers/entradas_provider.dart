import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/entrada_dao.dart';
import '../models/entrada_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class EntradasState {
  final List<Entrada> entradas;
  final bool          isLoading;
  final String?       error;
  final bool          guardando;

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

// ── Notifier (SQLite local) ───────────────────────────────────────────────────

class EntradasNotifier extends StateNotifier<EntradasState> {
  EntradasNotifier() : super(const EntradasState());
  final _dao = EntradaDao();

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rows = await _dao.listar();
      final list = rows.map((r) => Entrada.fromJson(r)).toList();
      state = state.copyWith(entradas: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> registrar(Map<String, dynamic> body) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await _dao.registrar(body);
      state = state.copyWith(guardando: false);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(guardando: false, error: e.toString());
      return false;
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      await _dao.eliminar(id);
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

final entradasProvider =
    StateNotifierProvider<EntradasNotifier, EntradasState>(
      (_) => EntradasNotifier(),
    );
