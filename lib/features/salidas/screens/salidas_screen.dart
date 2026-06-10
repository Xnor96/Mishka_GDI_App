import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/salidas_provider.dart';
import '../models/salida_models.dart';

const _kPageSize = 20;

/// P7 — Lista Ventas. Scaffold/AppBar/FAB los provee AppShell.
class SalidasScreen extends ConsumerStatefulWidget {
  const SalidasScreen({super.key});

  @override
  ConsumerState<SalidasScreen> createState() => _SalidasScreenState();
}

class _SalidasScreenState extends ConsumerState<SalidasScreen> {
  final _currency  = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFmt   = DateFormat('dd/MM/yyyy', 'es_MX');
  final _fmtShort  = DateFormat('dd/MM/yy', 'es_MX');
  String?   _filtroCat;
  String?   _filtroLugar;
  DateTime? _desde;
  DateTime? _hasta;
  int       _page = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(salidasProvider.notifier).cargar();
    });
    // Restaurar el último filtro de lugar persistido (si lo había)
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(AppConstants.keyFiltroLugar);
      if (saved != null && mounted) {
        setState(() => _filtroLugar = saved);
      }
    });
  }

  // ── Confirmar anulación (desde tabla escritorio) ──────────────────────────
  Future<void> _confirmarAnular(BuildContext context, Salida s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Anular venta'),
        content: Text(
            '¿Anular la venta de "${s.nombreProducto}"?\n'
            'El stock del producto se revertirá automáticamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Anular',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(salidasProvider.notifier).eliminar(s.id);
    }
  }

  // ── Filtrado ──────────────────────────────────────────────────────────────
  List<Salida> _filtradas(List<Salida> todas) {
    return todas.where((s) {
      if (_filtroCat   != null && s.nombreCategoria != _filtroCat)   return false;
      if (_filtroLugar != null && s.lugarVenta      != _filtroLugar) return false;
      if (_desde != null && s.fechaSalida.isBefore(_desde!))         return false;
      if (_hasta != null) {
        final fin = DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59);
        if (s.fechaSalida.isAfter(fin)) return false;
      }
      return true;
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(salidasProvider);

    return Column(
      children: [
        if (state.error != null) _buildErrorBanner(state.error!),
        _buildFiltros(state),
        _buildFiltroFechas(),
        Expanded(child: _buildContent(state)),
      ],
    );
  }

  // ── Filtros de categoría / lugar ──────────────────────────────────────────
  Widget _buildFiltros(SalidasState state) {
    final cats = state.salidas
        .map((s) => s.nombreCategoria)
        .toSet()
        .toList()
      ..sort();

    final lugares = state.salidas
        .map((s) => s.lugarVenta)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (cats.isEmpty && lugares.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (cats.isNotEmpty) ...[
            _chip('Todas', null, 'cat'),
            ...cats.map((c) => _chip(c, c, 'cat')),
          ],
          if (cats.isNotEmpty && lugares.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(width: 1, height: 24, color: const Color(0xFFDDDDDD)),
            const SizedBox(width: 12),
          ],
          if (lugares.isNotEmpty) ...[
            _chip('Todos los lugares', null, 'lugar'),
            ...lugares.map((l) => _chip(l, l, 'lugar')),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, String? value, String group) {
    final selected = group == 'cat' ? _filtroCat == value : _filtroLugar == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (group == 'cat') { _filtroCat   = value; }
            else                { _filtroLugar = value; }
            _page = 0;
          });
          // Persistir el filtro de lugar para que "Nueva venta" lo precargue
          if (group == 'lugar') {
            SharedPreferences.getInstance().then((p) {
              if (value == null) {
                p.remove(AppConstants.keyFiltroLugar);
              } else {
                p.setString(AppConstants.keyFiltroLugar, value);
              }
            });
          }
        },
        selectedColor: AppColors.colSalidas.withOpacity(0.15),
        checkmarkColor: AppColors.colSalidas,
        labelStyle: TextStyle(
          color:      selected ? AppColors.colSalidas : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
          fontSize: 12,
        ),
        side: BorderSide(
            color: selected ? AppColors.colSalidas : const Color(0xFFDDDDDD)),
        backgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  // ── Filtro de fechas ──────────────────────────────────────────────────────
  Widget _buildFiltroFechas() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          _fechaBtn(
            label: _desde != null
                ? 'Desde: ${_fmtShort.format(_desde!)}'
                : 'Desde',
            active: _desde != null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _desde ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (d != null) setState(() { _desde = d; _page = 0; });
            },
          ),
          const SizedBox(width: 6),
          _fechaBtn(
            label: _hasta != null
                ? 'Hasta: ${_fmtShort.format(_hasta!)}'
                : 'Hasta',
            active: _hasta != null,
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _hasta ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (d != null) setState(() { _hasta = d; _page = 0; });
            },
          ),
          if (_desde != null || _hasta != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => setState(() { _desde = null; _hasta = null; _page = 0; }),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDDDDDD)),
                ),
                child: const Icon(Icons.close, size: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fechaBtn({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.colSalidas.withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.colSalidas : const Color(0xFFDDDDDD),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.calendar_today_outlined,
              size: 12,
              color: active ? AppColors.colSalidas : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: active ? AppColors.colSalidas : AppColors.textSecondary,
                  fontWeight: active ? FontWeight.w700 : FontWeight.normal)),
        ]),
      ),
    );
  }

  // ── Paginación ────────────────────────────────────────────────────────────
  Widget _buildPaginacion(int page, int totalPages, int totalItems) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: page > 0
                ? () => setState(() => _page = page - 1)
                : null,
            color: AppColors.colSalidas,
            disabledColor: Colors.grey.shade300,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.colSalidas.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${page + 1} / $totalPages  ($totalItems)',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.colSalidas),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: page < totalPages - 1
                ? () => setState(() => _page = page + 1)
                : null,
            color: AppColors.colSalidas,
            disabledColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
          Expanded(child: Text(msg,
              style: const TextStyle(color: AppColors.stockCero, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => ref.read(salidasProvider.notifier).limpiarError(),
          ),
        ],
      ),
    );
  }

  // ── Contenido ─────────────────────────────────────────────────────────────
  Widget _buildContent(SalidasState state) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colSalidas));
    }

    final filtradas  = _filtradas(state.salidas);
    final totalPages = (filtradas.length / _kPageSize).ceil().clamp(1, 9999);
    final pagina     = _page.clamp(0, totalPages - 1);
    final paginadas  = filtradas
        .skip(pagina * _kPageSize)
        .take(_kPageSize)
        .toList();

    if (filtradas.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.point_of_sale_outlined, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Sin ventas registradas',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    final totalVentas   = filtradas.fold<double>(0, (s, v) => s + v.total);
    final totalUnidades = filtradas.fold<int>(0, (s, v) => s + v.cantidad);
    final isDesktop     = MediaQuery.of(context).size.width > 800;
    final hayPaginas    = filtradas.length > _kPageSize;

    return Column(
      children: [
        _buildResumen(totalVentas, totalUnidades, filtradas.length),
        if (hayPaginas) _buildPaginacion(pagina, totalPages, filtradas.length),
        Expanded(
            child: isDesktop ? _buildTabla(paginadas) : _buildLista(paginadas)),
        if (hayPaginas) _buildPaginacion(pagina, totalPages, filtradas.length),
      ],
    );
  }

  // ── Resumen rápido ────────────────────────────────────────────────────────
  Widget _buildResumen(double total, int unidades, int registros) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colSalidas.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colSalidas.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resItem('Ventas', '$registros', Icons.receipt_long_outlined),
          _divV(),
          _resItem('Piezas', '$unidades', Icons.diamond_outlined),
          _divV(),
          _resItem('Total', _currency.format(total), Icons.attach_money),
        ],
      ),
    );
  }

  Widget _resItem(String label, String value, IconData icon) => Column(
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.colSalidas),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary)),
      ]),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 14,
          color: AppColors.colSalidas)),
    ],
  );

  Widget _divV() => Container(
      width: 1, height: 30,
      color: AppColors.colSalidas.withOpacity(0.2));

  // ── Lista móvil ───────────────────────────────────────────────────────────
  Widget _buildLista(List<Salida> salidas) {
    return RefreshIndicator(
      color: AppColors.colSalidas,
      onRefresh: () => ref.read(salidasProvider.notifier).cargar(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
        itemCount: salidas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) => _SalidaCard(
            salida: salidas[i],
            dateFmt: _dateFmt,
            currency: _currency,
            onDelete: () => ref.read(salidasProvider.notifier).eliminar(salidas[i].id)),
      ),
    );
  }

  // ── Tabla escritorio ──────────────────────────────────────────────────────
  Widget _buildTabla(List<Salida> salidas) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      child: Card(
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.colSalidas.withOpacity(0.08)),
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Fecha',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Producto', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Cat.',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Cant.',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('P.Venta',  style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Desc.',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Total',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Lugar',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Pago',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('',         style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: salidas.map((s) => DataRow(cells: [
            DataCell(Text(_dateFmt.format(s.fechaSalida),
                style: const TextStyle(fontSize: 13))),
            DataCell(Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(s.nombreProducto,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(s.codigoProducto,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            )),
            DataCell(Text(s.nombreCategoria,
                style: const TextStyle(fontSize: 12))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.colSalidas.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('−${s.cantidad}',
                  style: const TextStyle(
                      color: AppColors.colSalidas,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            )),
            DataCell(Text(_currency.format(s.precioVenta),
                style: const TextStyle(fontSize: 13))),
            DataCell(Text(
              s.descuento > 0 ? _currency.format(s.descuento) : '—',
              style: TextStyle(
                  fontSize: 13,
                  color: s.descuento > 0
                      ? AppColors.stockBajo
                      : AppColors.textHint),
            )),
            DataCell(Text(_currency.format(s.total),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13))),
            DataCell(_LugarCell(lugar: s.lugarVenta)),
            DataCell(_PagoBadge(tipo: s.tipoPago)),
            DataCell(IconButton(
              tooltip: 'Anular venta',
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: AppColors.stockCero),
              onPressed: () => _confirmarAnular(context, s),
            )),
          ])).toList(),
        ),
      ),
    );
  }
}

// ── Helpers de badges ─────────────────────────────────────────────────────────

class _LugarCell extends StatelessWidget {
  final String lugar;
  const _LugarCell({required this.lugar});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    switch (lugar) {
      case 'ALL BAZAR': icon = Icons.store_outlined; break;
      case 'PINKSTORE': icon = Icons.shopping_bag_outlined; break;
      case 'PERSONAL':  icon = Icons.person_outline; break;
      default:          icon = Icons.location_on_outlined;
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: AppColors.textSecondary),
      const SizedBox(width: 3),
      Flexible(
        child: Text(lugar.isNotEmpty ? lugar : '—',
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ),
    ]);
  }
}

class _PagoBadge extends StatelessWidget {
  final String tipo;
  const _PagoBadge({required this.tipo});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (tipo) {
      case 'EFECTIVO':      color = AppColors.stockOk; break;
      case 'TRANSFERENCIA': color = AppColors.colProductos; break;
      case 'CLIP':          color = const Color(0xFFF57C00); break;
      default:              color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(tipo.isNotEmpty ? tipo : '—',
          style: TextStyle(
              fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

// ── Card móvil ────────────────────────────────────────────────────────────────

class _SalidaCard extends StatelessWidget {
  final Salida       salida;
  final DateFormat   dateFmt;
  final NumberFormat currency;
  final VoidCallback onDelete;

  const _SalidaCard(
      {required this.salida,
      required this.dateFmt,
      required this.currency,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final s = salida;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: AppColors.colSalidas.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: AppColors.colSalidas, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nombreProducto,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    Text(s.codigoProducto,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const SizedBox(width: 6),
                    _catBadge(s.nombreCategoria),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    _LugarCell(lugar: s.lugarVenta),
                    const SizedBox(width: 8),
                    _PagoBadge(tipo: s.tipoPago),
                  ]),
                  if (s.observaciones.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(s.observaciones,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(s.total),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.colSalidas)),
                const SizedBox(height: 3),
                if (s.descuento > 0)
                  Text('−${currency.format(s.descuento)}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.stockBajo)),
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.colSalidas.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text('−${s.cantidad}',
                      style: const TextStyle(
                          color: AppColors.colSalidas,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
                const SizedBox(height: 2),
                Text(dateFmt.format(s.fechaSalida),
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar venta'),
                        content: Text(
                            '¿Eliminar la venta de "${s.nombreProducto}"?\n'
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _catBadge(String cat) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: AppColors.colSalidas.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(cat,
            style: const TextStyle(
                fontSize: 10,
                color: AppColors.colSalidas,
                fontWeight: FontWeight.w600)),
      );
}
