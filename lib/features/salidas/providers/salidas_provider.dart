import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/venta_dao.dart';
import '../models/salida_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class SalidasState {
  /// Ventas con sus líneas. Reemplaza al legacy `salidas` (lista plana).
  final List<Venta> ventas;
  final bool    isLoading;
  final String? error;
  final bool    guardando;

  const SalidasState({
    this.ventas    = const [],
    this.isLoading = false,
    this.error,
    this.guardando = false,
  });

  SalidasState copyWith({
    List<Venta>? ventas,
    bool?        isLoading,
    String?      error,
    bool?        guardando,
    bool         clearError = false,
  }) => SalidasState(
    ventas:    ventas    ?? this.ventas,
    isLoading: isLoading ?? this.isLoading,
    error:     clearError ? null : (error ?? this.error),
    guardando: guardando ?? this.guardando,
  );
}

// ── Notifier (SQLite local, multi-ítem) ───────────────────────────────────────

class SalidasNotifier extends StateNotifier<SalidasState> {
  SalidasNotifier() : super(const SalidasState());
  final _dao = VentaDao();

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final rows = await _dao.listar();
      final list = rows.map(_rowToVenta).toList();
      state = state.copyWith(ventas: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Registra una venta multi-ítem.
  /// [venta] = header (fecha_venta, lugar_venta, tipo_pago, observaciones, usuario_registro).
  /// [lineas] = cada línea con id_producto, cantidad, precio_venta.
  Future<bool> registrar(
    Map<String, dynamic> venta,
    List<Map<String, dynamic>> lineas,
  ) async {
    state = state.copyWith(guardando: true, clearError: true);
    try {
      await _dao.registrar(venta, lineas);
      state = state.copyWith(guardando: false);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(guardando: false, error: e.toString());
      return false;
    }
  }

  /// Elimina una venta completa (revierte stock de todas sus líneas).
  Future<bool> eliminar(int idVenta) async {
    try {
      await _dao.eliminar(idVenta);
      state = state.copyWith(
        ventas: state.ventas.where((v) => v.id != idVenta).toList(),
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void limpiarError() => state = state.copyWith(clearError: true);

  Venta _rowToVenta(Map<String, dynamic> row) {
    final lineasRaw = (row['_lineas'] as List?) ?? const [];
    final lineas = [
      for (final l in lineasRaw) Salida.fromJson(l as Map<String, dynamic>),
    ];
    return Venta.fromJson(row, lineas);
  }
}

final salidasProvider =
    StateNotifierProvider<SalidasNotifier, SalidasState>(
      (_) => SalidasNotifier(),
    );
