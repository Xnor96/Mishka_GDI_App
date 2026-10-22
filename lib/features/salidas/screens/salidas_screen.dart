import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/salidas_provider.dart';
import '../models/salida_models.dart';

const _kPageSize = 20;

/// P7 — Lista Ventas (multi-ítem). Scaffold/AppBar/FAB los provee AppShell.
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
    SharedPreferences.getInstance().then((p) {
      final saved = p.getString(AppConstants.keyFiltroLugar);
      if (saved != null && mounted) {
        setState(() => _filtroLugar = saved);
      }
    });
  }

  // ── Confirmar anular venta ─────────────────────────────────────────────────
  Future<void> _confirmarAnular(Venta v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Anular venta'),
        content: Text(
            '¿Anular la venta del ${_dateFmt.format(v.fechaVenta)} '
            '(${v.numLineas} ítem${v.numLineas == 1 ? '' : 's'}, '
            'total ${_currency.format(v.total)})?\n\n'
            'El stock de los productos vendidos se devolverá al inventario.'),
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
      await ref.read(salidasProvider.notifier).eliminar(v.id);
    }
  }

  // ── Filtrado ──────────────────────────────────────────────────────────────
  List<Venta> _filtradas(List<Venta> todas) {
    return todas.where((v) {
      if (_filtroLugar != null && v.lugarVenta != _filtroLugar) return false;
      if (_filtroCat != null &&
          !v.lineas.any((l) => l.nombreCategoria == _filtroCat)) {
        return false;
      }
      if (_desde != null && v.fechaVenta.isBefore(_desde!)) return false;
      if (_hasta != null) {
        final fin = DateTime(_hasta!.year, _hasta!.month, _hasta!.day, 23, 59, 59);
        if (v.fechaVenta.isAfter(fin)) return false;
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
    final cats = <String>{
      for (final v in state.ventas)
        for (final l in v.lineas) l.nombreCategoria,
    }..removeWhere((c) => c.isEmpty);
    final catsList = cats.toList()..sort();

    final lugares = state.ventas
        .map((v) => v.lugarVenta)
        .where((l) => l.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (catsList.isEmpty && lugares.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          if (catsList.isNotEmpty) ...[
            _chip('Todas', null, 'cat'),
            ...catsList.map((c) => _chip(c, c, 'cat')),
          ],
          if (catsList.isNotEmpty && lugares.isNotEmpty) ...[
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

    final filtradas  = _filtradas(state.ventas);
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
    final totalPiezas   = filtradas.fold<int>(0, (s, v) => s + v.cantidadItems);
    final hayPaginas    = filtradas.length > _kPageSize;

    return Column(
      children: [
        _buildResumen(totalVentas, totalPiezas, filtradas.length),
        if (hayPaginas) _buildPaginacion(pagina, totalPages, filtradas.length),
        Expanded(child: _buildLista(paginadas)),
        if (hayPaginas) _buildPaginacion(pagina, totalPages, filtradas.length),
      ],
    );
  }

  // ── Resumen rápido ────────────────────────────────────────────────────────
  Widget _buildResumen(double total, int piezas, int registros) {
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
          _resItem('Piezas', '$piezas', Icons.diamond_outlined),
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

  // ── Lista ─────────────────────────────────────────────────────────────────
  Widget _buildLista(List<Venta> ventas) {
    return RefreshIndicator(
      color: AppColors.colSalidas,
      onRefresh: () => ref.read(salidasProvider.notifier).cargar(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
        itemCount: ventas.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _VentaCard(
          // Key estable por id de venta: evita que al borrar una venta
          // expandida, la siguiente herede el estado "expandido".
          key: ValueKey('venta-${ventas[i].id}'),
          venta: ventas[i],
          dateFmt: _dateFmt,
          currency: _currency,
          onDelete: () => _confirmarAnular(ventas[i]),
        ),
      ),
    );
  }
}

// ── Card de venta con expansión ──────────────────────────────────────────────

class _VentaCard extends StatelessWidget {
  final Venta        venta;
  final DateFormat   dateFmt;
  final NumberFormat currency;
  final VoidCallback onDelete;

  const _VentaCard({
    super.key,
    required this.venta,
    required this.dateFmt,
    required this.currency,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // Quitar los bordes grises que ExpansionTile pone por default
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          // Key estable para que el estado de expansión siga a la venta,
          // no a la posición en la lista.
          key: PageStorageKey('venta-expand-${venta.id}'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding:
              const EdgeInsets.fromLTRB(14, 0, 14, 10),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.colSalidas.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long,
                color: AppColors.colSalidas, size: 20),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(dateFmt.format(venta.fechaVenta),
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 8),
                  _tag(venta.lugarVenta, AppColors.colControl),
                  const SizedBox(width: 6),
                  _tag(venta.tipoPago, _pagoColor(venta.tipoPago)),
                ],
              ),
              const SizedBox(height: 2),
              Text(venta.resumenProductos,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                '${venta.numLineas} ítem${venta.numLineas == 1 ? '' : 's'} · '
                '${venta.cantidadItems} pza${venta.cantidadItems == 1 ? '' : 's'}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textHint)),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(currency.format(venta.total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.colSalidas)),
              const Icon(Icons.expand_more,
                  size: 18, color: AppColors.textHint),
            ],
          ),
          children: [
            const Divider(height: 1),
            const SizedBox(height: 6),
            ...venta.lineas.map((l) => _buildLineaRow(l)),
            const SizedBox(height: 6),
            if (venta.observaciones.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(venta.observaciones,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.stockCero),
                label: const Text('Anular venta',
                    style: TextStyle(color: AppColors.stockCero)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineaRow(Salida l) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.nombreProducto,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${l.codigoProducto} · ${l.nombreCategoria}',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('x${l.cantidad}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.colSalidas)),
          ),
          SizedBox(
            width: 70,
            child: Text('\$${l.precioVenta.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          SizedBox(
            width: 80,
            child: Text('\$${l.total.toStringAsFixed(2)}',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _tag(String texto, Color color) {
    if (texto.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }

  Color _pagoColor(String tipo) {
    switch (tipo) {
      case 'EFECTIVO':      return AppColors.stockOk;
      case 'TRANSFERENCIA': return AppColors.colProductos;
      case 'CLIP':          return AppColors.colEntradas;
      default:              return AppColors.textSecondary;
    }
  }
}
