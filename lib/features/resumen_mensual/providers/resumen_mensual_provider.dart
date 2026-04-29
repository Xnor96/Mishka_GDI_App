import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/resumen_mensual_models.dart';

class ResumenMensualState {
  final ResumenMensual? actual;
  final bool            isLoading;
  final String?         error;
  final bool            generando;

  const ResumenMensualState({
    this.actual    = null,
    this.isLoading = false,
    this.error,
    this.generando = false,
  });

  ResumenMensualState copyWith({
    ResumenMensual? actual,
    bool?           isLoading,
    String?         error,
    bool?           generando,
    bool            clearError = false,
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

  Future<void> cargarActual() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await ApiClient.instance.get('/api/resumen-mensual/actual');
      final data = res.data['data'] as Map<String, dynamic>;
      state = state.copyWith(
          actual: ResumenMensual.fromJson(data), isLoading: false);
    } catch (e) {
      // 404 = todavía no hay resumen del mes → no es error grave
      state = state.copyWith(
          isLoading: false, clearActual: true, clearError: true);
    }
  }

  Future<void> cargarPorMes(int mes, int anio) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res  = await ApiClient.instance
          .get('/api/resumen-mensual/$mes/$anio');
      final data = res.data['data'] as Map<String, dynamic>;
      state = state.copyWith(
          actual: ResumenMensual.fromJson(data), isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> generar(Map<String, dynamic> body) async {
    state = state.copyWith(generando: true, clearError: true);
    try {
      final res  = await ApiClient.instance
          .post('/api/resumen-mensual/generar', data: body);
      final data = res.data['data'] as Map<String, dynamic>;
      state = state.copyWith(
          generando: false, actual: ResumenMensual.fromJson(data));
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
