import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/control_diario_models.dart';

// ── Filtros disponibles ────────────────────────────────────────────────────

enum ControlFiltro { todos, hoy, verbena }

// ── State ─────────────────────────────────────────────────────────────────────

class ControlDiarioState {
  final List<ControlDiario> registros;
  final double              totalEntrada;
  final double              totalSalida;
  final double              balance;
  final bool                isLoading;
  final String?             error;
  final bool                guardando;
  final ControlFiltro       filtro;

  const ControlDiarioState({
    this.registros    = const [],
    this.totalEntrada = 0,
    this.totalSalida  = 0,
    this.balance      = 0,
    this.isLoading    = false,
    this.error,
    this.guardando    = false,
    this.filtro       = ControlFiltro.todos,
  });

  ControlDiarioState copyWith({
    List<ControlDiario>? registros,
    double?              totalEntrada,
    double?              totalSalida,
    double?              balance,
    bool?                isLoading,
    String?              error,
    bool?                guardando,
    ControlFiltro?       filtro,
    bool                 clearError = false,
  }) => ControlDiarioState(
    registros:    registros    ?? this.registros,
    totalEntrada: totalEntrada ?? this.totalEntrada,
    totalSalida:  totalSalida  ?? this.totalSalida,
    balance:      balance      ?? this.balance,
    isLoading:    isLoading    ?? this.isLoading,
    error:        clearError ? null : (error ?? this.error),
    guardando:    guardando    ?? this.guardando,
    filtro:       filtro       ?? this.filtro,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ControlDiarioNotifier extends StateNotifier<ControlDiarioState> {
  ControlDiarioNotifier() : super(const ControlDiarioState());

  Future<void> cargar([ControlFiltro? filtro]) async {
    final f = filtro ?? state.filtro;
    state = state.copyWith(isLoading: true, clearError: true, filtro: f);

    final endpoint = switch (f) {
      ControlFiltro.hoy     => '/api/control-diario/hoy',
      ControlFiltro.verbena => '/api/control-diario/verbena',
      ControlFiltro.todos   => '/api/control-diario',
    };

    try {
      final res  = await ApiClient.instance.get(endpoint);
      final data = res.data as Map<String, dynamic>;
      final list = (data['data'] as List)
          .map((j) => ControlDiario.fromJson(j as Map<String, dynamic>))
          .toList();
      list.sort((a, b) => b.fecha.compareTo(a.fecha));

      state = state.copyWith(
        registros:    list,
        totalEntrada: (data['total_entrada'] as num? ?? 0).toDouble(),
        totalSalida:  (data['total_salida']  as num? ?? 0).toDouble(),
        balance:      (data['balance']        as num? ?? 0).toDouble(),
        isLoading:    false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> registrar(Map<String, dynamic> body) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await ApiClient.instance.post('/api/control-diario', data: body);
      state = state.copyWith(guardando: false);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(guardando: false, error: e.toString());
      return false;
    }
  }

  Future<bool> generarDesdeVentas(String fecha) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await ApiClient.instance
          .post('/api/control-diario/generar/$fecha', data: {});
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
      await ApiClient.instance.delete('/api/control-diario/$id');
      final nuevos = state.registros.where((c) => c.id != id).toList();
      final te = nuevos.fold<double>(0, (s, c) => s + c.montoEntrada);
      final ts = nuevos.fold<double>(0, (s, c) => s + c.montoSalida);
      state = state.copyWith(
        registros:    nuevos,
        totalEntrada: te,
        totalSalida:  ts,
        balance:      te - ts,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void cambiarFiltro(ControlFiltro f) => cargar(f);

  void limpiarError() => state = state.copyWith(clearError: true);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final controlDiarioProvider =
    StateNotifierProvider<ControlDiarioNotifier, ControlDiarioState>(
      (_) => ControlDiarioNotifier(),
    );
