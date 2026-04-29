import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/reportes_models.dart';

class ReportesState {
  // Tab 1: inventario
  final List<ReporteInventarioItem> inventario;
  // Tab 2: movimientos
  final List<ReporteMovimientoItem> movimientos;
  // Tab 3: más vendidos
  final List<ReporteVendidoItem> masVendidos;
  // Tab 4: valoración
  final List<ReporteValoracionItem> valoracion;

  final bool    isLoadingInv;
  final bool    isLoadingMov;
  final bool    isLoadingVen;
  final bool    isLoadingVal;
  final String? errorInv;
  final String? errorMov;
  final String? errorVen;
  final String? errorVal;

  const ReportesState({
    this.inventario    = const [],
    this.movimientos   = const [],
    this.masVendidos   = const [],
    this.valoracion    = const [],
    this.isLoadingInv  = false,
    this.isLoadingMov  = false,
    this.isLoadingVen  = false,
    this.isLoadingVal  = false,
    this.errorInv,
    this.errorMov,
    this.errorVen,
    this.errorVal,
  });

  ReportesState copyWith({
    List<ReporteInventarioItem>? inventario,
    List<ReporteMovimientoItem>? movimientos,
    List<ReporteVendidoItem>?    masVendidos,
    List<ReporteValoracionItem>? valoracion,
    bool? isLoadingInv, bool? isLoadingMov,
    bool? isLoadingVen, bool? isLoadingVal,
    String? errorInv, String? errorMov,
    String? errorVen, String? errorVal,
    bool clearErrorInv = false, bool clearErrorMov = false,
    bool clearErrorVen = false, bool clearErrorVal = false,
  }) => ReportesState(
    inventario:   inventario   ?? this.inventario,
    movimientos:  movimientos  ?? this.movimientos,
    masVendidos:  masVendidos  ?? this.masVendidos,
    valoracion:   valoracion   ?? this.valoracion,
    isLoadingInv: isLoadingInv ?? this.isLoadingInv,
    isLoadingMov: isLoadingMov ?? this.isLoadingMov,
    isLoadingVen: isLoadingVen ?? this.isLoadingVen,
    isLoadingVal: isLoadingVal ?? this.isLoadingVal,
    errorInv: clearErrorInv ? null : (errorInv ?? this.errorInv),
    errorMov: clearErrorMov ? null : (errorMov ?? this.errorMov),
    errorVen: clearErrorVen ? null : (errorVen ?? this.errorVen),
    errorVal: clearErrorVal ? null : (errorVal ?? this.errorVal),
  );
}

class ReportesNotifier extends StateNotifier<ReportesState> {
  ReportesNotifier() : super(const ReportesState());

  // ── Tab 1: Inventario valorado ─────────────────────────────────────────────
  Future<void> cargarInventario() async {
    state = state.copyWith(isLoadingInv: true, clearErrorInv: true);
    try {
      final res  = await ApiClient.instance.get('/api/reportes/inventario-actual');
      final list = (res.data['data'] as List)
          .map((j) => ReporteInventarioItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(inventario: list, isLoadingInv: false);
    } catch (e) {
      state = state.copyWith(isLoadingInv: false, errorInv: e.toString());
    }
  }

  // ── Tab 2: Movimientos ─────────────────────────────────────────────────────
  Future<void> cargarMovimientos(String inicio, String fin) async {
    state = state.copyWith(isLoadingMov: true, clearErrorMov: true);
    try {
      final res  = await ApiClient.instance
          .get('/api/reportes/movimientos/$inicio/$fin');
      final list = (res.data['data'] as List)
          .map((j) => ReporteMovimientoItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(movimientos: list, isLoadingMov: false);
    } catch (e) {
      state = state.copyWith(isLoadingMov: false, errorMov: e.toString());
    }
  }

  // ── Tab 3: Más vendidos ────────────────────────────────────────────────────
  Future<void> cargarMasVendidos({int limite = 20}) async {
    state = state.copyWith(isLoadingVen: true, clearErrorVen: true);
    try {
      final res  = await ApiClient.instance.get(
          '/api/reportes/productos-mas-vendidos',
          queryParameters: {'limite': limite});
      final list = (res.data['data'] as List)
          .map((j) => ReporteVendidoItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(masVendidos: list, isLoadingVen: false);
    } catch (e) {
      state = state.copyWith(isLoadingVen: false, errorVen: e.toString());
    }
  }

  // ── Tab 4: Valoración ──────────────────────────────────────────────────────
  Future<void> cargarValoracion() async {
    state = state.copyWith(isLoadingVal: true, clearErrorVal: true);
    try {
      final res  = await ApiClient.instance
          .get('/api/reportes/valoracion-inventario');
      final list = (res.data['data'] as List)
          .map((j) => ReporteValoracionItem.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(valoracion: list, isLoadingVal: false);
    } catch (e) {
      state = state.copyWith(isLoadingVal: false, errorVal: e.toString());
    }
  }
}

final reportesProvider =
    StateNotifierProvider<ReportesNotifier, ReportesState>(
      (_) => ReportesNotifier(),
    );
