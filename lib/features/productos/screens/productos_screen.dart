import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/productos_provider.dart';
import '../models/producto_models.dart';

/// Contenido de Lista Productos — Scaffold/AppBar/FAB los provee AppShell.
class ProductosScreen extends ConsumerStatefulWidget {
  const ProductosScreen({super.key});

  @override
  ConsumerState<ProductosScreen> createState() => _ProductosScreenState();
}

class _ProductosScreenState extends ConsumerState<ProductosScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    if (q.trim().isEmpty) {
      ref.read(productosProvider.notifier).resetear();
      return;
    }
    ref.read(productosProvider.notifier).buscar(q.trim());
  }

  void _onCategoria(int? id) =>
      ref.read(productosProvider.notifier).filtrarCategoria(id);

  void _irADetalle(Producto p) => context.push('/productos/${p.id}', extra: p);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productosProvider);
    return Column(
      children: [
        _buildSearchBar(state),
        if (state.hasBuscado) _buildCategoryChips(state.categoriaFiltro),
        if (state.error != null) _buildErrorBanner(state.error!),
        Expanded(child: _buildContent(state)),
      ],
    );
  }

  // ── Barra de búsqueda ─────────────────────────────────────────────────────
  Widget _buildSearchBar(ProductosState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              onSubmitted: _onSearch,
              decoration: InputDecoration(
                hintText: 'Buscar por código o nombre…',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(productosProvider.notifier).resetear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: state.isLoading ? null : () {
              _searchCtrl.clear();
              ref.read(productosProvider.notifier).cargar();
            },
            icon: const Icon(Icons.list_alt, size: 18),
            label: const Text('Ver todos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Chips de categoría ────────────────────────────────────────────────────
  Widget _buildCategoryChips(int? selected) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        children: [
          _chip('Todas', null, selected),
          ...AppConstants.categorias.entries.map((e) => _chip(e.value, e.key, selected)),
        ],
      ),
    );
  }

  Widget _chip(String label, int? id, int? selected) {
    final isSelected = selected == id;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _onCategoria(id),
        selectedColor: AppColors.primary.withOpacity(0.18),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(color: isSelected ? AppColors.primary : const Color(0xFFDDDDDD)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.stockCero.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stockCero.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.stockCero, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(color: AppColors.stockCero, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => ref.read(productosProvider.notifier).limpiarError(),
          ),
        ],
      ),
    );
  }

  // ── Contenido principal ───────────────────────────────────────────────────
  Widget _buildContent(ProductosState state) {
    if (!state.hasBuscado) return _buildEstadoInicial();
    if (state.isLoading)   return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (state.filtrados.isEmpty) return _buildVacio();

    final isDesktop = MediaQuery.of(context).size.width > 700;
    return isDesktop ? _buildTabla(state.filtrados) : _buildLista(state.filtrados);
  }

  Widget _buildEstadoInicial() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: AppColors.colProductos.withOpacity(0.1), shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search, size: 40, color: AppColors.colProductos),
        ),
        const SizedBox(height: 20),
        const Text('Busca un producto',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text(
          'Escribe un código o nombre, o presiona "Ver todos".',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => ref.read(productosProvider.notifier).cargar(),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Ver todos los productos'),
        ),
      ],
    ),
  );

  Widget _buildVacio() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text('Sin resultados', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
      ],
    ),
  );

  Widget _buildLista(List<Producto> productos) => RefreshIndicator(
    onRefresh: () => ref.read(productosProvider.notifier).cargar(),
    child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: productos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) => _ProductoCard(
        producto: productos[i],
        onTap: () => _irADetalle(productos[i]),
      ),
    ),
  );

  Widget _buildTabla(List<Producto> productos) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    child: Card(
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceVariant),
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('Código',    style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Nombre',    style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Categoría', style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Precio',    style: TextStyle(fontWeight: FontWeight.w700))),
          DataColumn(label: Text('Stock',     style: TextStyle(fontWeight: FontWeight.w700))),
        ],
        rows: productos.map((p) => DataRow(
          onSelectChanged: (_) => _irADetalle(p),
          cells: [
            DataCell(Text(p.codigo, style: const TextStyle(fontFamily: 'monospace', fontSize: 13))),
            DataCell(SizedBox(width: 200, child: Text(p.nombre, overflow: TextOverflow.ellipsis))),
            DataCell(Text(p.categoriaNombre)),
            DataCell(Text('\$${p.precioUnitario.toStringAsFixed(2)}')),
            DataCell(_StockBadge(stock: p.stockActual)),
          ],
        )).toList(),
      ),
    ),
  );
}

// ── Card de producto ──────────────────────────────────────────────────────────

class _ProductoCard extends StatelessWidget {
  final Producto    producto;
  final VoidCallback onTap;
  const _ProductoCard({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = producto;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.colProductos.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.diamond_outlined, color: AppColors.colProductos, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(p.codigo, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: AppColors.colProductos.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(p.categoriaNombre, style: const TextStyle(fontSize: 10, color: AppColors.colProductos, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('\$${p.precioUnitario.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                _StockBadge(stock: p.stockActual),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge de stock ────────────────────────────────────────────────────────────

class _StockBadge extends StatelessWidget {
  final int stock;
  const _StockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (stock == 0)      { color = AppColors.stockCero; label = 'Sin stock'; }
    else if (stock <= 3) { color = AppColors.stockBajo; label = 'Stock: $stock'; }
    else                 { color = AppColors.stockOk;   label = 'Stock: $stock'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
