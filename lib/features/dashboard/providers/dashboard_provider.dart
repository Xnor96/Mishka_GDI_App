import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../models/dashboard_models.dart';

// ── Estado ────────────────────────────────────────────────────────
class DashboardState {
  final bool   isLoading;
  final String? error;

  final List<AlertaStockBajo>    alertas;
  final ResumenMensual?          resumenActual;
  final List<ControlDiario>      controlHoy;
  final double                   totalEntradaHoy;
  final double                   totalSalidaHoy;
  final List<ValoracionCategoria> valoracion;

  const DashboardState({
    this.isLoading      = false,
    this.error,
    this.alertas        = const [],
    this.resumenActual,
    this.controlHoy     = const [],
    this.totalEntradaHoy = 0,
    this.totalSalidaHoy  = 0,
    this.valoracion     = const [],
  });

  DashboardState copyWith({
    bool?                    isLoading,
    String?                  error,
    List<AlertaStockBajo>?   alertas,
    ResumenMensual?          resumenActual,
    List<ControlDiario>?     controlHoy,
    double?                  totalEntradaHoy,
    double?                  totalSalidaHoy,
    List<ValoracionCategoria>? valoracion,
  }) => DashboardState(
    isLoading:       isLoading       ?? this.isLoading,
    error:           error,
    alertas:         alertas         ?? this.alertas,
    resumenActual:   resumenActual   ?? this.resumenActual,
    controlHoy:      controlHoy      ?? this.controlHoy,
    totalEntradaHoy: totalEntradaHoy ?? this.totalEntradaHoy,
    totalSalidaHoy:  totalSalidaHoy  ?? this.totalSalidaHoy,
    valoracion:      valoracion      ?? this.valoracion,
  );
}

// ── Notifier ──────────────────────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());

  final _dio = ApiClient().dio;

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true);
    try {
      // Lanzar todas las peticiones en paralelo
      final results = await Future.wait([
        _dio.get('/api/alertas/stock-bajo'),
        _dio.get('/api/resumen-mensual/actual'),
        _dio.get('/api/control-diario/hoy'),
        _dio.get('/api/reportes/valoracion-inventario'),
      ]);

      // Alertas
      final alertasData = results[0].data['stock_bajo'] as List? ?? [];
      final alertas = alertasData
          .map((e) => AlertaStockBajo.fromJson(e))
          .toList();

      // Resumen mensual actual
      ResumenMensual? resumen;
      final resumenData = results[1].data['data'];
      if (resumenData != null) {
        resumen = ResumenMensual.fromJson(resumenData);
      }

      // Control de hoy
      final controlData = results[2].data['data'] as List? ?? [];
      final controles = controlData
          .map((e) => ControlDiario.fromJson(e))
          .toList();
      final totalEntrada = (results[2].data['total_entrada'] ?? 0).toDouble();
      final totalSalida  = (results[2].data['total_salida']  ?? 0).toDouble();

      // Valoración
      final valorData = results[3].data['data'] as List? ?? [];
      final valoracion = valorData
          .map((e) => ValoracionCategoria.fromJson(e))
          .toList();

      state = state.copyWith(
        isLoading:       false,
        alertas:         alertas,
        resumenActual:   resumen,
        controlHoy:      controles,
        totalEntradaHoy: totalEntrada,
        totalSalidaHoy:  totalSalida,
        valoracion:      valoracion,
      );
    } on DioException catch (e) {
      final msg = e.response?.data?['error'] ?? 'Error al cargar el dashboard';
      state = state.copyWith(isLoading: false, error: msg);
    } catch (_) {
      state = state.copyWith(
          isLoading: false, error: 'Error inesperado al cargar el dashboard');
    }
  }

  void limpiarError() => state = state.copyWith(error: null);
}

// ── Provider ──────────────────────────────────────────────────────
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
