import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/control_diario_provider.dart';
import '../models/control_diario_models.dart';

/// P9 — Control Diario. Scaffold/AppBar/FAB los provee AppShell.
class ControlDiarioScreen extends ConsumerStatefulWidget {
  const ControlDiarioScreen({super.key});

  @override
  ConsumerState<ControlDiarioScreen> createState() =>
      _ControlDiarioScreenState();
}

class _ControlDiarioScreenState extends ConsumerState<ControlDiarioScreen> {
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  final _dateFmt  = DateFormat('dd/MM/yyyy', 'es_MX');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(controlDiarioProvider.notifier).cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(controlDiarioProvider);
    return Column(
      children: [
        if (state.error != null) _buildErrorBanner(state.error!),
        _buildFiltroTabs(state),
        if (state.registros.isNotEmpty || !state.isLoading)
          _buildResumenGlobal(state),
        Expanded(child: _buildContent(state)),
      ],
    );
  }

  // ── Tabs de filtro ────────────────────────────────────────────────────────
  Widget _buildFiltroTabs(ControlDiarioState state) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: ControlFiltro.values.map((f) {
          final selected = state.filtro == f;
          final label    = switch (f) {
            ControlFiltro.todos   => 'Todos',
            ControlFiltro.hoy     => 'Hoy',
            ControlFiltro.verbena => '🎪 Verbena',
          };
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(label),
              selected: selected,
              onSelected: (_) =>
                  ref.read(controlDiarioProvider.notifier).cambiarFiltro(f),
              selectedColor: AppColors.colControl.withOpacity(0.15),
              checkmarkColor: AppColors.colControl,
              labelStyle: TextStyle(
                color:      selected ? AppColors.colControl : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                fontSize: 13,
              ),
              side: BorderSide(
                  color: selected
                      ? AppColors.colControl
                      : const Color(0xFFDDDDDD)),
              backgroundColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Resumen global (totales de la respuesta backend) ──────────────────────
  Widget _buildResumenGlobal(ControlDiarioState state) {
    final balPos = state.balance >= 0;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.colControl.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colControl.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _resItem('Entradas', _currency.format(state.totalEntrada),
              Icons.arrow_downward_rounded, AppColors.colEntradas),
          _divV(),
          _resItem('Salidas', _currency.format(state.totalSalida),
              Icons.arrow_upward_rounded, AppColors.colSalidas),
          _divV(),
          _resItem('Balance', _currency.format(state.balance.abs()),
              balPos ? Icons.trending_up : Icons.trending_down,
              balPos ? AppColors.colEntradas : AppColors.stockCero),
        ],
      ),
    );
  }

  Widget _resItem(String label, String value, IconData icon, Color color) =>
      Column(
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ]),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 13, color: color)),
        ],
      );

  Widget _divV() => Container(
      width: 1, height: 30, color: AppColors.colControl.withOpacity(0.2));

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
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: AppColors.stockCero, fontSize: 13))),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () =>
                ref.read(controlDiarioProvider.notifier).limpiarError(),
          ),
        ],
      ),
    );
  }

  // ── Contenido ─────────────────────────────────────────────────────────────
  Widget _buildContent(ControlDiarioState state) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.colControl));
    }
    if (state.registros.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined,
                size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Sin registros',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
          ],
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;
    return isDesktop
        ? _buildTabla(state.registros)
        : _buildLista(state.registros);
  }

  // ── Lista móvil ───────────────────────────────────────────────────────────
  Widget _buildLista(List<ControlDiario> lista) {
    return RefreshIndicator(
      color: AppColors.colControl,
      onRefresh: () => ref.read(controlDiarioProvider.notifier).cargar(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: lista.length,
        separatorBuilder: (_, __) => const SizedBox(height: 4),
        itemBuilder: (_, i) =>
            _ControlCard(
                ctrl: lista[i],
                dateFmt: _dateFmt,
                currency: _currency,
                onDelete: () => ref.read(controlDiarioProvider.notifier).eliminar(lista[i].id)),
      ),
    );
  }

  // ── Tabla escritorio ──────────────────────────────────────────────────────
  Widget _buildTabla(List<ControlDiario> lista) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Card(
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AppColors.colControl.withOpacity(0.08)),
          columnSpacing: 16,
          columns: const [
            DataColumn(label: Text('Fecha',       style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Descripción', style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Entrada',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Salida',      style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Balance',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Verbena',     style: TextStyle(fontWeight: FontWeight.w700))),
            DataColumn(label: Text('Usuario',     style: TextStyle(fontWeight: FontWeight.w700))),
          ],
          rows: lista.map((c) {
            final bal = c.balance;
            return DataRow(cells: [
              DataCell(Text(_dateFmt.format(c.fecha),
                  style: const TextStyle(fontSize: 13))),
              DataCell(Text(c.descripcion,
                  style: const TextStyle(fontSize: 13),
                  maxLines: 2, overflow: TextOverflow.ellipsis)),
              DataCell(Text(_currency.format(c.montoEntrada),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.colEntradas))),
              DataCell(Text(_currency.format(c.montoSalida),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.colSalidas))),
              DataCell(Text(
                (bal >= 0 ? '+' : '') + _currency.format(bal),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: bal >= 0
                        ? AppColors.colEntradas
                        : AppColors.stockCero),
              )),
              DataCell(c.esVerbena
                  ? const Icon(Icons.celebration,
                      color: AppColors.accent, size: 18)
                  : const SizedBox.shrink()),
              DataCell(Text(c.usuarioRegistro,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ── Card móvil ────────────────────────────────────────────────────────────────

class _ControlCard extends StatelessWidget {
  final ControlDiario ctrl;
  final DateFormat    dateFmt;
  final NumberFormat  currency;
  final VoidCallback  onDelete;

  const _ControlCard(
      {required this.ctrl,
      required this.dateFmt,
      required this.currency,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final c   = ctrl;
    final bal = c.balance;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícono
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.colControl.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    c.esVerbena
                        ? Icons.celebration
                        : Icons.bar_chart_outlined,
                    color: c.esVerbena
                        ? AppColors.accent
                        : AppColors.colControl,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(c.descripcion,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (c.esVerbena) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('VERBENA',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ]),
                      Text(dateFmt.format(c.fecha),
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Balance
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      (bal >= 0 ? '+' : '') + currency.format(bal),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: bal >= 0
                              ? AppColors.colEntradas
                              : AppColors.stockCero),
                    ),
                    const SizedBox(height: 2),
                    Text(dateFmt.format(c.fecha),
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textHint)),
                  ],
                ),
              ],
            ),
            // Entradas / Salidas inline
            const SizedBox(height: 8),
            Row(
              children: [
                _montoChip('↓ ${currency.format(c.montoEntrada)}',
                    AppColors.colEntradas),
                const SizedBox(width: 8),
                _montoChip('↑ ${currency.format(c.montoSalida)}',
                    AppColors.colSalidas),
                if (c.observaciones.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(c.observaciones,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textHint),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Eliminar movimiento'),
                        content: Text(
                            '¿Eliminar "${c.descripcion}"?\n'
                            'Esta acción no puede deshacerse.'),
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

  Widget _montoChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}
