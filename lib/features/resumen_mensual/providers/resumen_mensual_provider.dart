import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/resumen_mensual_dao.dart';
import '../models/resumen_mensual_models.dart';

class ResumenMensualState {
  final ResumenMensual? actual;
  final bool            isLoading;
  final String?         error;
  final bool            generando;

  const ResumenMensualState({
    this.actual,
    this.isLoading = false,
    this.error,
    this.generando = false,
  });

  ResumenMensualState copyWith({
    ResumenMensual? actual,
    bool?           isLoading,
    String?         error,
    bool?           generando,
    bool            clearError  = false,
    bool            clearActual = false,
  }) => ResumenMensualState(
    actual:    clearActual ? null : (actual ?? this.actual),
    isLoading: isLoading ?? this.isLoading,
    error:     clearError ? null : (error ?? this.error),
    generando: generando ?? this.generando,
  );
}

class ResumenMensualNotifier extends StateNotifier<ResumenMensualState> {
  ResumenMensualNotifier() : super(const ResumenMensualState());
  final _dao = ResumenMensualDao();

  Future<void> cargarActual() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final row = await _dao.actual();
      state = state.copyWith(
        actual: row == null ? null : ResumenMensual.fromJson(row),
        clearActual: row == null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> cargarPorMes(int mes, int anio) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final row = await _dao.porMesAnio(mes, anio);
      state = state.copyWith(
        actual: row == null ? null : ResumenMensual.fromJson(row),
        clearActual: row == null,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> generar(Map<String, dynamic> body) async {
    state = state.copyWith(generando: true, clearError: true);
    try {
      final row = await _dao.generar(body);
      state = state.copyWith(
        generando: false,
        actual: ResumenMensual.fromJson(row),
      );
      return true;
    } catch (e) {
      state = state.copyWith(generando: false, error: e.toString());
      return false;
    }
  }

  void limpiarError() => state = state.copyWith(clearError: true);
}

final resumenMensualProvider =
    StateNotifierProvider<ResumenMensualNotifier, ResumenMensualState>(
      (_) => ResumenMensualNotifier(),
    );
