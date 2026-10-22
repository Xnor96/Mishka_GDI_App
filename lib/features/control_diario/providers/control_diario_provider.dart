import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/control_diario_dao.dart';
import '../models/control_diario_models.dart';

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

// ── Notifier (SQLite local) ───────────────────────────────────────────────────

class ControlDiarioNotifier extends StateNotifier<ControlDiarioState> {
  ControlDiarioNotifier() : super(const ControlDiarioState());
  final _dao = ControlDiarioDao();

  Future<void> cargar([ControlFiltro? filtro]) async {
    final f = filtro ?? state.filtro;
    state = state.copyWith(isLoading: true, clearError: true, filtro: f);
    try {
      final rows = await _dao.listar(
        soloHoy:     f == ControlFiltro.hoy,
        soloVerbena: f == ControlFiltro.verbena,
      );
      final list = rows.map((r) => ControlDiario.fromJson(r)).toList();
      list.sort((a, b) => b.fecha.compareTo(a.fecha));

      final tot = await _dao.totales(
        soloHoy:     f == ControlFiltro.hoy,
        soloVerbena: f == ControlFiltro.verbena,
      );
      state = state.copyWith(
        registros:    list,
        totalEntrada: tot['te']!,
        totalSalida:  tot['ts']!,
        balance:      tot['balance']!,
        isLoading:    false,
      );
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

  Future<bool> generarDesdeVentas(String fecha) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      final id = await _dao.generarDesdeVentas(fecha);
      state = state.copyWith(guardando: false);
      if (id == null) {
        state = state.copyWith(error: 'No hay ventas registradas ese día');
        return false;
      }
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

final controlDiarioProvider =
    StateNotifierProvider<ControlDiarioNotifier, ControlDiarioState>(
      (_) => ControlDiarioNotifier(),
    );
