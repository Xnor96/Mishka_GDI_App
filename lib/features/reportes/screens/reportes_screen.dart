import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/reportes_models.dart';
import '../providers/reportes_provider.dart';

/// P11 — Reportes con 4 tabs. Scaffold/AppBar los provee AppShell.
class ReportesScreen extends ConsumerStatefulWidget {
  const ReportesScreen({super.key});

  @override
  ConsumerState<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends ConsumerState<ReportesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFmt  = DateFormat('dd/MM/yyyy', 'es_MX');

  // Filtros de movimientos
  DateTime _movInicio = DateTime.now().subtract(const Duration(days: 30));
  DateTime _movFin    = DateTime.now();
  bool     _movCargado = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _cargarTab(_tabCtrl.index);
    });
    // Carga inicial del primer tab
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarTab(0));
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _cargarTab(int idx) {
    final n = ref.read(reportesProvider.notifier);
    switch (idx) {
      case 0: n.cargarInventario(); break;
      case 1: /* movimientos se cargan con el botón */ break;
      case 2: n.cargarMasVendidos(); break;
      case 3: n.cargarValoracion(); break;
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // TabBar dentro del contenido (no del AppBar)
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: AppColors.colReportes,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.colReportes,
            isScrollable: MediaQuery.of(context).size.width < 500,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2_outlined, size: 18),
                  text: 'Inventario'),
              Tab(icon: Icon(Icons.swap_vert_outlined, size: 18),
                  text: 'Movimientos'),
              Tab(icon: Icon(Icons.star_outline_rounded, size: 18),
                  text: 'Más vendidos'),
              Tab(icon: Icon(Icons.pie_chart_outline, size: 18),
                  text: 'Valoración'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _TabInventario(currency: _currency),
              _TabMovimientos(
                currency: _currency,
                dateFmt: _dateFmt,
                inicio: _movInicio,
                fin: _movFin,
                cargado: _movCargado,
                onPickInicio: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _movInicio,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('es', 'MX'),
                  );
                  if (d != null) setState(() => _movInicio = d);
                },
                onPickFin: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _movFin,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('es', 'MX'),
                  );
                  if (d != null) setState(() => _movFin = d);
                },
                onBuscar: () {
                  setState(() => _movCargado = true);
                  ref.read(reportesProvider.notifier).cargarMovimientos(
                    _movInicio.toIso8601String().split('T').first,
                    _movFin.toIso8601String().split('T').first,
                  );
                },
              ),
              _TabVendidos(currency: _currency),
              _TabValoracion(currency: _currency),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Utilidad CSV ──────────────────────────────────────────────────────────────

void _exportarCsv(BuildContext context, String csv, String nombre) {
  Clipboard.setData(ClipboardData(text: csv));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text('$nombre copiado al portapapeles')),
      ]),
      backgroundColor: AppColors.colReportes,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ),
  );
}

Widget _csvButton({
  required BuildContext context,
  required VoidCallback onPressed,
}) {
  return TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.file_copy_outlined, size: 15),
    label: const Text('CSV', style: TextStyle(fontSize: 12)),
    style: TextButton.styleFrom(
      foregroundColor: AppColors.colReportes,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1: Inventario valorado
// ─────────────────────────────────────────────────────────────────────────────

class _TabInventario extends ConsumerWidget {
  final NumberFormat currency;
  const _TabInventario({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportesProvider);

    if (state.isLoadingInv) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colReportes));
    }
    if (state.errorInv != null) {
      return _centeredMsg(state.errorInv!, AppColors.stockCero);
    }
    if (state.inventario.isEmpty) {
      return _centeredMsg('Sin datos de inventario', AppColors.textHint);
    }

    final totalValor = state.inventario
        .fold<double>(0, (s, i) => s + i.valorTotal);
    final isDesktop  = MediaQuery.of(context).size.width > 700;

    return Column(
      children: [
        // Resumen + botón CSV
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.colReportes.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.colReportes.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _resItem('Productos', '${state.inventario.length}',
                        Icons.inventory_2_outlined),
                    _divV(),
                    _resItem('Valor total', _fmt(totalValor),
                        Icons.attach_money),
                  ],
                ),
              ),
              _csvButton(
                context: context,
                onPressed: () => _exportarCsv(
                  context,
                  _buildCsvInventario(state.inventario),
                  'Inventario',
                ),
              ),
            ],
          ),
        ),
        // Tabla / Lista
        Expanded(
          child: RefreshIndicator(
            color: AppColors.colReportes,
            onRefresh: () =>
                ref.read(reportesProvider.notifier).cargarInventario(),
            child: isDesktop
                ? _tablaInventario(state.inventario)
                : _listaInventario(state.inventario),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) =>
      NumberFormat.currency(locale: 'es_MX', symbol: '\$').format(v);

  String _buildCsvInventario(List<ReporteInventarioItem> items) {
    final buf = StringBuffer();
    buf.writeln('Código,Nombre,Categoría,Stock,Precio Unitario,Valor Total');
    for (final i in items) {
      buf.writeln(
        '"${i.codigo}","${i.nombre}","${i.categoria}",'
        '${i.stockActual},${i.precioUnitario.toStringAsFixed(2)},'
        '${i.valorTotal.toStringAsFixed(2)}',
      );
    }
    return buf.toString();
  }

  Widget _listaInventario(List<ReporteInventarioItem> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          child: ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.colReportes.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text('${item.stockActual}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.colReportes)),
              ),
            ),
            title: Text(item.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            subtitle: Text('${item.codigo} · ${item.categoria}',
                style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(_fmt(item.valorTotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.colReportes,
                        fontSize: 13)),
                Text('\$${item.precioUnitario.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tablaInventario(List<ReporteInventarioItem> items) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      child: Card(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(
              AppColors.colReportes.withOpacity(0.08)),
          columnSpacing: 14,
          columns: const [
            DataColumn(label: Text('Código',   style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Nombre',   style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Cat.',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Stock',    style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('P. Unit',  style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Valor',    style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: items.map((item) => DataRow(cells: [
            DataCell(Text(item.codigo,
                style: const TextStyle(fontSize: 12,
                    fontWeight: FontWeight.w600))),
            DataCell(Text(item.nombre,
                style: const TextStyle(fontSize: 12),
                maxLines: 2, overflow: TextOverflow.ellipsis)),
            DataCell(Text(item.categoria,
                style: const TextStyle(fontSize: 12))),
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: item.stockActual > 0
                    ? AppColors.colReportes.withOpacity(0.1)
                    : AppColors.stockCero.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text('${item.stockActual}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: item.stockActual > 0
                          ? AppColors.colReportes
                          : AppColors.stockCero)),
            )),
            DataCell(Text('\$${item.precioUnitario.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12))),
            DataCell(Text(_fmt(item.valorTotal),
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.colReportes,
                    fontSize: 12))),
          ])).toList(),
        ),
      ),
    );
  }

  Widget _resItem(String label, String value, IconData icon) => Column(
    children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.colReportes),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(
            fontSize: 11, color: AppColors.textSecondary)),
      ]),
      Text(value, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 14,
          color: AppColors.colReportes)),
    ],
  );

  Widget _divV() => Container(
      width: 1, height: 28, color: AppColors.colReportes.withOpacity(0.2));
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2: Movimientos
// ─────────────────────────────────────────────────────────────────────────────

class _TabMovimientos extends ConsumerWidget {
  final NumberFormat currency;
  final DateFormat   dateFmt;
  final DateTime     inicio;
  final DateTime     fin;
  final bool         cargado;
  final VoidCallback onPickInicio;
  final VoidCallback onPickFin;
  final VoidCallback onBuscar;

  const _TabMovimientos({
    required this.currency,
    required this.dateFmt,
    required this.inicio,
    required this.fin,
    required this.cargado,
    required this.onPickInicio,
    required this.onPickFin,
    required this.onBuscar,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportesProvider);
    return Column(
      children: [
        // Filtro de fechas + CSV
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onPickInicio,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Desde',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: Text(dateFmt.format(inicio),
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: onPickFin,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'Hasta',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    child: Text(dateFmt.format(fin),
                        style: const TextStyle(fontSize: 14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onBuscar,
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.colReportes),
                child: const Text('Buscar'),
              ),
              if (cargado && state.movimientos.isNotEmpty) ...[
                const SizedBox(width: 4),
                _csvButton(
                  context: context,
                  onPressed: () => _exportarCsv(
                    context,
                    _buildCsvMovimientos(state.movimientos, dateFmt),
                    'Movimientos',
                  ),
                ),
              ],
            ],
          ),
        ),
        // Contenido
        Expanded(child: _buildBody(context, state)),
      ],
    );
  }

  String _buildCsvMovimientos(
      List<ReporteMovimientoItem> items, DateFormat fmt) {
    final buf = StringBuffer();
    buf.writeln('Fecha,Tipo,Código,Nombre,Categoría,Cantidad,Total');
    for (final m in items) {
      buf.writeln(
        '"${fmt.format(m.fecha)}","${m.tipo}","${m.codigo}","${m.nombre}",'
        '"${m.categoria}",${m.cantidad},${m.total.toStringAsFixed(2)}',
      );
    }
    return buf.toString();
  }

  Widget _buildBody(BuildContext context, ReportesState state) {
    if (state.isLoadingMov) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colReportes));
    }
    if (!cargado) {
      return _centeredMsg('Selecciona un rango y presiona Buscar',
          AppColors.textSecondary);
    }
    if (state.errorMov != null) {
      return _centeredMsg(state.errorMov!, AppColors.stockCero);
    }
    if (state.movimientos.isEmpty) {
      return _centeredMsg('Sin movimientos en el período', AppColors.textHint);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
      itemCount: state.movimientos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) {
        final m    = state.movimientos[i];
        final isE  = m.tipo == 'ENTRADA';
        final color = isE ? AppColors.colEntradas : AppColors.colSalidas;
        return Card(
          child: ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(
                isE ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: color, size: 18),
            ),
            title: Text(m.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
                '${m.codigo} · ${m.categoria} · ${dateFmt.format(m.fecha)}',
                style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(currency.format(m.total),
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 13)),
                Text('×${m.cantidad}',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3: Más vendidos
// ─────────────────────────────────────────────────────────────────────────────

class _TabVendidos extends ConsumerWidget {
  final NumberFormat currency;
  const _TabVendidos({required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportesProvider);

    if (state.isLoadingVen) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colReportes));
    }
    if (state.errorVen != null) {
      return _centeredMsg(state.errorVen!, AppColors.stockCero);
    }
    if (state.masVendidos.isEmpty) {
      return _centeredMsg('Sin ventas registradas', AppColors.textHint);
    }

    final maxVendido = state.masVendidos
        .fold<int>(0, (m, v) => v.totalVendido > m ? v.totalVendido : m);

    return RefreshIndicator(
      color: AppColors.colReportes,
      onRefresh: () => ref.read(reportesProvider.notifier).cargarMasVendidos(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        itemCount: state.masVendidos.length + 1, // +1 for header row
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) {
          if (i == 0) {
            // Header with export button
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _csvButton(
                    context: context,
                    onPressed: () => _exportarCsv(
                      context,
                      _buildCsvVendidos(state.masVendidos),
                      'Más vendidos',
                    ),
                  ),
                ],
              ),
            );
          }
          final v    = state.masVendidos[i - 1];
          final idx  = i - 1;
          final pct  = maxVendido > 0 ? v.totalVendido / maxVendido : 0.0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Ranking
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: idx < 3
                          ? AppColors.accent.withOpacity(0.15)
                          : AppColors.colReportes.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${idx + 1}',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: idx < 3
                                  ? AppColors.accent
                                  : AppColors.colReportes,
                              fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Nombre + barra
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.nombre,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${v.codigo} · ${v.categoria}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 5,
                            backgroundColor:
                                AppColors.colReportes.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                idx < 3 ? AppColors.accent : AppColors.colReportes),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Stats
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${v.totalVendido} uds',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.colReportes,
                              fontSize: 13)),
                      Text(currency.format(v.totalIngresos),
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _buildCsvVendidos(List<ReporteVendidoItem> items) {
    final buf = StringBuffer();
    buf.writeln('#,Código,Nombre,Categoría,Unidades Vendidas,Total Ingresos');
    for (var i = 0; i < items.length; i++) {
      final v = items[i];
      buf.writeln(
        '${i + 1},"${v.codigo}","${v.nombre}","${v.categoria}",'
        '${v.totalVendido},${v.totalIngresos.toStringAsFixed(2)}',
      );
    }
    return buf.toString();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4: Valoración por categoría
// ─────────────────────────────────────────────────────────────────────────────

class _TabValoracion extends ConsumerWidget {
  final NumberFormat currency;
  const _TabValoracion({required this.currency});

  static const _catColors = [
    AppColors.colProductos,
    AppColors.colEntradas,
    AppColors.colSalidas,
    AppColors.colControl,
    AppColors.colReportes,
    AppColors.accent,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(reportesProvider);

    if (state.isLoadingVal) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colReportes));
    }
    if (state.errorVal != null) {
      return _centeredMsg(state.errorVal!, AppColors.stockCero);
    }
    if (state.valoracion.isEmpty) {
      return _centeredMsg('Sin datos de valoración', AppColors.textHint);
    }

    final totalValor = state.valoracion
        .fold<double>(0, (s, v) => s + v.valorTotal);

    return RefreshIndicator(
      color: AppColors.colReportes,
      onRefresh: () => ref.read(reportesProvider.notifier).cargarValoracion(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
        children: [
          // Resumen total + CSV
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.colReportes.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.colReportes.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Valor total del inventario',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(currency.format(totalValor),
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.colReportes)),
                    ],
                  ),
                ),
                _csvButton(
                  context: context,
                  onPressed: () => _exportarCsv(
                    context,
                    _buildCsvValoracion(state.valoracion, totalValor),
                    'Valoración',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Barras por categoría
          ...state.valoracion.asMap().entries.map((e) {
            final i    = e.key;
            final v    = e.value;
            final pct  = totalValor > 0 ? v.valorTotal / totalValor : 0.0;
            final color = _catColors[i % _catColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            Container(
                              width: 10, height: 10,
                              decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(v.nombreCategoria,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: color)),
                          ]),
                          Text(currency.format(v.valorTotal),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: color)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: color.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('Productos', '${v.totalProductos}',
                              Icons.inventory_2_outlined, color),
                          _statItem('Unidades', '${v.totalUnidades}',
                              Icons.diamond_outlined, color),
                          _statItem('%',
                              '${(pct * 100).toStringAsFixed(1)}%',
                              Icons.pie_chart_outline, color),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _buildCsvValoracion(
      List<ReporteValoracionItem> items, double total) {
    final buf = StringBuffer();
    buf.writeln('Categoría,Productos,Unidades,Valor Total,% del Total');
    for (final v in items) {
      final pct = total > 0 ? (v.valorTotal / total * 100) : 0.0;
      buf.writeln(
        '"${v.nombreCategoria}",${v.totalProductos},${v.totalUnidades},'
        '${v.valorTotal.toStringAsFixed(2)},${pct.toStringAsFixed(1)}%',
      );
    }
    return buf.toString();
  }

  Widget _statItem(
      String label, String value, IconData icon, Color color) => Column(
    children: [
      Icon(icon, size: 14, color: color.withOpacity(0.7)),
      const SizedBox(height: 2),
      Text(value,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: color)),
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary)),
    ],
  );
}

// ── Helper global ─────────────────────────────────────────────────────────────

Widget _centeredMsg(String msg, Color color) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(msg,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: color)),
    ),
  );
}
