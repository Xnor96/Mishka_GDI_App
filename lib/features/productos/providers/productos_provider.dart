import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/producto_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ProductosState {
  final List<Producto> todos;          // lista completa (sin filtrar)
  final List<Producto> filtrados;      // lista visible tras búsqueda/filtro
  final bool   isLoading;
  final String? error;
  final int?   categoriaFiltro;       // null = todas
  final String  busqueda;
  final bool   hasBuscado;            // true cuando el usuario inició una búsqueda/carga

  const ProductosState({
    this.todos        = const [],
    this.filtrados    = const [],
    this.isLoading    = false,
    this.error,
    this.categoriaFiltro,
    this.busqueda     = '',
    this.hasBuscado   = false,
  });

  ProductosState copyWith({
    List<Producto>? todos,
    List<Producto>? filtrados,
    bool?   isLoading,
    String? error,
    int?    categoriaFiltro,
    bool    clearCategoria = false,
    String? busqueda,
    bool?   hasBuscado,
  }) =>
    ProductosState(
      todos:           todos           ?? this.todos,
      filtrados:       filtrados       ?? this.filtrados,
      isLoading:       isLoading       ?? this.isLoading,
      error:           error,
      categoriaFiltro: clearCategoria ? null : (categoriaFiltro ?? this.categoriaFiltro),
      busqueda:        busqueda        ?? this.busqueda,
      hasBuscado:      hasBuscado      ?? this.hasBuscado,
    );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ProductosNotifier extends StateNotifier<ProductosState> {
  ProductosNotifier() : super(const ProductosState());

  // ── Cargar todos ────────────────────────────────────────────────────────────
  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, error: null, hasBuscado: true);
    try {
      final res = await ApiClient.instance.get('/api/productos');
      final list = (res.data['data'] as List)
          .map((j) => Producto.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(todos: list, isLoading: false);
      _aplicarFiltros();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // ── Buscar (servidor) ───────────────────────────────────────────────────────
  Future<void> buscar(String q) async {
    state = state.copyWith(busqueda: q, hasBuscado: true);
    if (q.isEmpty) {
      _aplicarFiltros();
      return;
    }
    try {
      final res = await ApiClient.instance
          .get('/api/productos/buscar', queryParameters: {'q': q});
      final list = (res.data['data'] as List)
          .map((j) => Producto.fromJson(j as Map<String, dynamic>))
          .toList();
      // Aplica también filtro de categoría local sobre resultados
      final filtrado = state.categoriaFiltro == null
          ? list
          : list.where((p) => p.idCategoria == state.categoriaFiltro).toList();
      state = state.copyWith(filtrados: filtrado);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // ── Filtrar categoría (local) ───────────────────────────────────────────────
  void filtrarCategoria(int? idCategoria) {
    if (idCategoria == null) {
      state = state.copyWith(clearCategoria: true);
    } else {
      state = state.copyWith(categoriaFiltro: idCategoria);
    }
    _aplicarFiltros();
  }

  // ── Crear ───────────────────────────────────────────────────────────────────
  Future<bool> crear(Map<String, dynamic> body) async {
    try {
      await ApiClient.instance.post('/api/productos', data: body);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ── Actualizar ──────────────────────────────────────────────────────────────
  Future<bool> actualizar(int id, Map<String, dynamic> body) async {
    try {
      await ApiClient.instance.put('/api/productos/$id', data: body);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ── Eliminar ────────────────────────────────────────────────────────────────
  Future<bool> eliminar(int id) async {
    try {
      await ApiClient.instance.delete('/api/productos/$id');
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  // ── Privado: aplica filtros locales ─────────────────────────────────────────
  void _aplicarFiltros() {
    var lista = state.todos;
    if (state.categoriaFiltro != null) {
      lista = lista.where((p) => p.idCategoria == state.categoriaFiltro).toList();
    }
    state = state.copyWith(filtrados: lista);
  }

  /// Regresa al estado inicial (pantalla de búsqueda vacía).
  void resetear() => state = const ProductosState();

  void limpiarError() => state = state.copyWith(error: null);
}

// ── Provider ──────────────────────────────────────────────────────────────────

final productosProvider =
    StateNotifierProvider<ProductosNotifier, ProductosState>(
      (_) => ProductosNotifier(),
    );
