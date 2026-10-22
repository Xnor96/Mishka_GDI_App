import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/dao/producto_dao.dart';
import '../models/producto_models.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class ProductosState {
  final List<Producto> todos;
  final List<Producto> filtrados;
  final bool   isLoading;
  final String? error;
  final int?   categoriaFiltro;
  final String  busqueda;
  final bool   hasBuscado;

  const ProductosState({
    this.todos      = const [],
    this.filtrados  = const [],
    this.isLoading  = false,
    this.error,
    this.categoriaFiltro,
    this.busqueda   = '',
    this.hasBuscado = false,
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

// ── Notifier (SQLite local) ───────────────────────────────────────────────────

class ProductosNotifier extends StateNotifier<ProductosState> {
  ProductosNotifier() : super(const ProductosState());
  final _dao = ProductoDao();

  Future<void> cargar() async {
    state = state.copyWith(isLoading: true, error: null, hasBuscado: true);
    try {
      final rows = await _dao.listar();
      final list = rows.map((r) => Producto.fromJson(r)).toList();
      state = state.copyWith(todos: list, isLoading: false);
      _aplicarFiltros();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> buscar(String q) async {
    state = state.copyWith(busqueda: q, hasBuscado: true);
    if (q.isEmpty) { _aplicarFiltros(); return; }
    try {
      final rows = await _dao.buscar(q);
      final list = rows.map((r) => Producto.fromJson(r)).toList();
      final filtrado = state.categoriaFiltro == null
          ? list
          : list.where((p) => p.idCategoria == state.categoriaFiltro).toList();
      state = state.copyWith(filtrados: filtrado);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  void filtrarCategoria(int? idCategoria) {
    if (idCategoria == null) {
      state = state.copyWith(clearCategoria: true);
    } else {
      state = state.copyWith(categoriaFiltro: idCategoria);
    }
    _aplicarFiltros();
  }

  Future<bool> crear(Map<String, dynamic> body) async {
    try {
      await _dao.crear(body);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> actualizar(int id, Map<String, dynamic> body) async {
    try {
      await _dao.actualizar(id, body);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  Future<bool> eliminar(int id) async {
    try {
      await _dao.eliminar(id);
      await cargar();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _aplicarFiltros() {
    var lista = state.todos;
    if (state.categoriaFiltro != null) {
      lista = lista.where((p) => p.idCategoria == state.categoriaFiltro).toList();
    }
    state = state.copyWith(filtrados: lista);
  }

  void resetear() => state = const ProductosState();
  void limpiarError() => state = state.copyWith(error: null);
}

final productosProvider =
    StateNotifierProvider<ProductosNotifier, ProductosState>(
      (_) => ProductosNotifier(),
    );
