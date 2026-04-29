import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/entradas_provider.dart';
import '../models/entrada_models.dart';

const _kPageSize = 20;

/// P5 — Lista Entradas. Scaffold/AppBar/FAB los provee AppShell.
class EntradasScreen extends ConsumerStatefulWidget {
  const EntradasScreen({super.key});

  @override
  ConsumerState<EntradasScreen> createState() => _EntradasScreenState();
}

class _EntradasScreenState extends ConsumerState<EntradasScreen> {
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFmt  = DateFormat('dd/MM/yyyy', 'es_MX');

  // Filtros
  String?   _filtroCat;
  DateTime? _desde;
  DateTime? _hasta;

  // Paginación
  int _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(entradasProvider.notifier).cargar();
    });
  }

  // ── Resetear página cuando cambian los filtros ────────────────────
  void _resetPage() => setState(() => _page = 0);

  // ── Lista filtrada (antes de paginar) ─────────────────────────────
  List<Entrada> _filtradas(List<Entrada> todas) {
    return todas.where((e) {
      if (_filtroCat != null && e.nombreCategoria != _filtroCat) return false;
      if (_desde != null && e.fechaEntrada.isBefore(_desde!)) return false;
      if (_hasta != null) {
        final fin = DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59);
        if (e.fechaEntrada.isAfter(fin)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(entradasProvider);
    final filtradas = _filtradas(state.entradas);
    final totalPages = (filtradas.length / _kPageSize).ceil().clamp(1, 9999);
    final pagina = _page.clamp(0, totalPages - 1);
    final paginadas = filtradas.skip(pagina * _kPageSize).take(_kPageSize).toList();

    return Column(
      children: [
        if (state.error != null) _buildErrorBanner(state.error!),
        _buildFiltros(state),
        _buildFiltroFechas(),
        Expanded(child: _buildContent(state, paginadas, filtradas.length)),
        if (filtradas.length > _kPageSize)
          _buildPaginacion(pagina, totalPages, filtradas.length),
      ],
    );
  }

  // ── Filtros de categoría ──────────────────────────────────────────
  Widget _buildFiltros(EntradasState state) {
    final cats = state.entradas.map((e) => e.nombreCategoria).toSet().toList()..sort();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(children: [
        _chip('Todas', null),
        ...cats.map((c) => _chip(c, c)),
      ]),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _filtroCat == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) { setState(() => _filtroCat = value); _resetPage(); },
        selectedColor: AppColors.colEntradas.withOpacity(0.18),
        checkmarkColor: AppColors.colEntradas,
        labelStyle: TextStyle(
          color: selected ? AppColors.colEntradas : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(color: selected ? AppColors.colEntradas : const Color(0xFFDDDDDD)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // ── Filtro de fechas ──────────────────────────────────────────────
  Widget _buildFiltroFechas() {
    final activo = _desde != null || _hasta != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          // Desde
          Expanded(child: _fechaBtn(
            label: _desde != null ? 'Desde: ${_dateFmt.format(_desde!)}' : 'Desde',
            active: _desde != null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _desde ?? DateTime.now().subtract(const Duration(days: 30)),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (d != null) { setState(() => _desde = d); _resetPage(); }
            },
          )),
          const SizedBox(width: 8),
          // Hasta
          Expanded(child: _fechaBtn(
            label: _hasta != null ? 'Hasta: ${_dateFmt.format(_hasta!)}' : 'Hasta',
            active: _hasta != null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _hasta ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (d != null) { setState(() => _hasta = d); _resetPage(); }
            },
          )),
          // Limpiar fechas
          if (activo) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Limpiar fechas',
              style: IconButton.styleFrom(
                backgroundColor: AppColors.stockCero.withOpacity(0.08),
                foregroundColor: AppColors.stockCero,
              ),
              onPressed: () { setState(() { _desde = null; _hasta = null; }); _resetPage(); },
            ),
          ],
        ],
      ),
    );
  }

  Widget _fechaBtn({required String label, required bool active, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.colEntradas.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.colEntradas : const Color(0xFFDDDDDD),
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.calendar_today_outlined, size: 13,
              color: active ? AppColors.colEntradas : AppColors.textSecondary),
          const SizedBox(width: 5),
          Flexible(child: Text(label, style: TextStyle(
            fontSize: 12,
            color: active ? AppColors.colEntradas : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ), overflow: TextOverflow.ellipsis)),
        ]),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.stockCero.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.stockCero.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.stockCero, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(color: AppColors.stockCero, fontSize: 13))),
        IconButton(
          icon: const Icon(Icons.close, size: 16),
          onPressed: () => ref.read(entradasProvider.notifier).limpiarError(),
        ),
      ]),
    );
  }

  // ── Contenido ─────────────────────────────────────────────────────
  Widget _buildContent(EntradasState state, List<Entrada> pagina, int total) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.colEntradas));
    }
    if (pagina.isEmpty && total == 0) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.arrow_downward_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(_desde != null || _hasta != null
              ? 'Sin entradas en el período seleccionado'
              : 'Sin entradas registradas',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ));
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    return isDesktop ? _buildTabla(pagina) : _buildLista(pagina);
  }

  // ── Paginación ────────────────────────────────────────────────────
  Widget _buildPaginacion(int page, int totalPages, int totalItems) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$totalItems registros',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: page > 0 ? () => setState(() => _page = page - 1) : null,
              iconSize: 20,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.colEntradas.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${page + 1} / $totalPages',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.colEntradas)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: page < totalPages - 1
                  ? () => setState(() => _page = page + 1)
                  : null,
              iconSize: 20,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Lista móvil ───────────────────────────────────────────────────
  Widget _buildLista(List<Entrada> entradas) {
    return RefreshIndicator(
      color: AppColors.colEntradas,
      onRefresh: () => ref.read(entradasProvider.notifier).cargar(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: entradas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _EntradaCard(
            entrada: entradas[i],
            dateFmt: _dateFmt,
            currency: _currency,
            onDelete: () => ref.read(entradasProvider.notifier).eliminar(entradas[i].id)),
      ),
    );
  }

  // ── Tabla escritorio ──────────────────────────────────────────────
  Widget _buildTabla(List<Entrada> entradas) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Card(
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.colEntradas.withOpacity(0.08)),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Fecha',      style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Producto',   style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Categoría',  style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Cant.',      style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Precio c/u', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Usuario',    style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: entradas.map((e) => DataRow(cells: [
            DataCell(Text(_dateFmt.format(e.fechaEntrada),
                style: const TextStyle(fontSize: 13))),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(e.nombreProducto,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(e.codigoProducto,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            )),
            DataCell(Text(e.nombreCategoria, style: const TextStyle(fontSize: 13))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.colEntradas.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('+${e.cantidad}',
                  style: const TextStyle(
                      color: AppColors.colEntradas,
                      fontWeight: FontWeight.w700, fontSize: 13)),
            )),
            DataCell(Text(
              e.precioUnitario != null ? _currency.format(e.precioUnitario) : '—',
              style: TextStyle(
                  fontSize: 13,
                  color: e.precioUnitario != null
                      ? AppColors.textPrimary
                      : AppColors.textHint),
            )),
            DataCell(Text(e.usuarioRegistro,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary))),
          ])).toList(),
        ),
      ),
    );
  }
}

// ── Card móvil ────────────────────────────────────────────────────────────────

class _EntradaCard extends StatelessWidget {
  final Entrada      entrada;
  final DateFormat   dateFmt;
  final NumberFormat currency;
  final VoidCallback onDelete;

  const _EntradaCard(
      {required this.entrada,
      required this.dateFmt,
      required this.currency,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final e = entrada;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.colEntradas.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: AppColors.colEntradas, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.nombreProducto,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Text(e.codigoProducto,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(width: 6),
                _catBadge(e.nombreCategoria),
              ]),
              if (e.observaciones.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(e.observaciones,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.colEntradas.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('+${e.cantidad}',
                  style: const TextStyle(
                      color: AppColors.colEntradas,
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ),
            const SizedBox(height: 4),
            Text(
              e.precioUnitario != null
                  ? currency.format(e.precioUnitario)
                  : 'Sin precio',
              style: TextStyle(
                  fontSize: 12,
                  color: e.precioUnitario != null
                      ? AppColors.textSecondary
                      : AppColors.textHint),
            ),
            const SizedBox(height: 2),
            Text(dateFmt.format(e.fechaEntrada),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Eliminar entrada'),
                    content: Text(
                        '¿Eliminar la entrada de "${e.nombreProducto}"?\n'
                        'El stock se revertirá automáticamente.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancelar')),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Eliminar',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (ok == true) onDelete();
              },
              child: const Icon(Icons.delete_outline,
                  size: 16, color: AppColors.textHint),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _catBadge(String cat) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.colEntradas.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(cat,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.colEntradas,
                fontWeight: FontWeight.w600)),
      );
}
