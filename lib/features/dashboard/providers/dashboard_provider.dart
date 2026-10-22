import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/dashboard_dao.dart';
import '../../../core/database/dao/resumen_mensual_dao.dart';
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
    bool                     clearResumen = false,
  }) => DashboardState(
    isLoading:       isLoading       ?? this.isLoading,
    error:           error,
    alertas:         alertas         ?? this.alertas,
    resumenActual:   clearResumen ? null : (resumenActual ?? this.resumenActual),
    controlHoy:      controlHoy      ?? this.controlHoy,
    totalEntradaHoy: totalEntradaHoy ?? this.totalEntradaHoy,
    totalSalidaHoy:  totalSalidaHoy  ?? this.totalSalidaHoy,
    valoracion:      valoracion      ?? this.valoracion,
  );
}

// ── Notifier (SQLite local) ───────────────────────────────────────
class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());
  final _dao        = DashboardDao();
  final _resumenDao = ResumenMensualDao();

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _dao.alertasStockBajo(),
        _resumenDao.actual(),
        _dao.controlHoy(),
        _dao.valoracionPorCategoria(),
      ]);

      final alertas = (results[0] as List<Map<String, dynamic>>)
          .map((e) => AlertaStockBajo.fromJson(e))
          .toList();

      final resumenRow = results[1] as Map<String, dynamic>?;
      final resumen = resumenRow == null ? null : ResumenMensual.fromJson(resumenRow);

      final control = results[2] as Map<String, dynamic>;
      final controles = (control['data'] as List)
          .map((e) => ControlDiario.fromJson(e as Map<String, dynamic>))
          .toList();
      final totalEntrada = (control['total_entrada'] as num).toDouble();
      final totalSalida  = (control['total_salida']  as num).toDouble();

      final valoracion = (results[3] as List<Map<String, dynamic>>)
          .map((e) => ValoracionCategoria.fromJson(e))
          .toList();

      state = state.copyWith(
        isLoading:       false,
        alertas:         alertas,
        resumenActual:   resumen,
        clearResumen:    resumen == null,
        controlHoy:      controles,
        totalEntradaHoy: totalEntrada,
        totalSalidaHoy:  totalSalida,
        valoracion:      valoracion,
      );
    } catch (e) {
      state = state.copyWith(
          isLoading: false, error: 'Error al cargar el dashboard: $e');
    }
  }

  void limpiarError() => state = state.copyWith(error: null);
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>(
  (ref) => DashboardNotifier(),
);
