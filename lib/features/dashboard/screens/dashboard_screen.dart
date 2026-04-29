import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../models/dashboard_models.dart';
import '../providers/dashboard_provider.dart';

/// Contenido del Dashboard — el Scaffold/AppBar/Sidebar lo provee AppShell.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');
  String _username = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).cargar();
    });
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _username = prefs.getString(AppConstants.keyUsername) ?? 'Usuario');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    return _buildBody(state);
  }

  // ── Cuerpo ────────────────────────────────────────────────────────
  Widget _buildBody(DashboardState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(state.error!, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(dashboardProvider.notifier).cargar(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(dashboardProvider.notifier).cargar(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildGreeting(),
            // Banner de alerta crítica si hay productos sin stock
            if (state.alertas.any((a) => a.stockActual == 0)) ...[
              const SizedBox(height: 16),
              _buildAlertaBanner(state.alertas),
            ],
            const SizedBox(height: 20),
            _buildResumenCards(state),
            const SizedBox(height: 24),
            _buildAlertasSection(state.alertas),
            const SizedBox(height: 24),
            _buildValoracionSection(state.valoracion),
            const SizedBox(height: 24),
            _buildControlHoySection(state),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ── Saludo ────────────────────────────────────────────────────────
  Widget _buildGreeting() {
    final hora   = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días'
                 : hora < 19 ? 'Buenas tardes'
                             : 'Buenas noches';
    final fecha = DateFormat("EEEE d 'de' MMMM, yyyy", 'es_MX').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$saludo, $_username 👋',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        Text(fecha, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ],
    );
  }

  // ── Cards de resumen mensual ──────────────────────────────────────
  Widget _buildResumenCards(DashboardState state) {
    final r = state.resumenActual;
    return LayoutBuilder(builder: (context, constraints) {
      final crossCount = constraints.maxWidth > 600 ? 4 : 2;
      return GridView.count(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _SummaryCard(label: 'Ingresos del mes',   value: _currency.format(r?.totalIngresos ?? 0),        icon: Icons.trending_up,                      color: AppColors.colEntradas),
          _SummaryCard(label: 'Gastos fijos',        value: _currency.format(r?.totalGastosFijos ?? 0),     icon: Icons.account_balance_outlined,          color: AppColors.colControl),
          _SummaryCard(label: 'Gastos variables',    value: _currency.format(r?.totalGastosVariables ?? 0), icon: Icons.receipt_long_outlined,             color: AppColors.stockBajo),
          _SummaryCard(
            label: 'Balance',
            value: _currency.format(r?.balance ?? 0),
            icon:  Icons.account_balance_wallet_outlined,
            color: (r?.balance ?? 0) >= 0 ? AppColors.colEntradas : AppColors.stockCero,
          ),
        ],
      );
    });
  }

  // ── Banner de críticos (solo cuando hay stock = 0) ───────────────
  Widget _buildAlertaBanner(List<AlertaStockBajo> alertas) {
    final sinStock = alertas.where((a) => a.stockActual == 0).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.stockCero,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$sinStock ${sinStock == 1 ? 'producto sin stock' : 'productos sin stock'} — requieren reabastecimiento urgente',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Alertas de stock ──────────────────────────────────────────────
  Widget _buildAlertasSection(List<AlertaStockBajo> alertas) {
    final sinStock  = alertas.where((a) => a.stockActual == 0).toList();
    final bajo      = alertas.where((a) => a.stockActual > 0).toList();
    final headerColor = sinStock.isNotEmpty ? AppColors.stockCero : AppColors.stockBajo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.warning_amber_rounded, color: headerColor, size: 20),
          const SizedBox(width: 8),
          Text('Alertas de stock', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (alertas.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: headerColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: headerColor.withOpacity(0.3)),
              ),
              child: Text(
                '${alertas.length} producto${alertas.length != 1 ? 's' : ''}',
                style: TextStyle(fontSize: 11, color: headerColor, fontWeight: FontWeight.w700),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        if (alertas.isEmpty)
          _EmptyCard(icon: Icons.check_circle_outline, color: AppColors.colEntradas, text: 'Todo el inventario tiene stock suficiente')
        else ...[
          if (sinStock.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Sin stock', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.stockCero)),
            ),
            ...sinStock.map((a) => _buildAlertaTile(a)),
            if (bajo.isNotEmpty) const SizedBox(height: 8),
          ],
          if (bajo.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Stock bajo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.stockBajo)),
            ),
            ...bajo.map((a) => _buildAlertaTile(a)),
          ],
        ],
      ],
    );
  }

  Widget _buildAlertaTile(AlertaStockBajo a) {
    final color = a.stockActual == 0 ? AppColors.stockCero : AppColors.stockBajo;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.inventory_2_outlined, color: color, size: 18),
        ),
        title: Text(a.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${a.codigo} · ${a.categoria}', style: const TextStyle(fontSize: 11)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
          child: Text(
            a.stockActual == 0 ? 'SIN STOCK' : 'Stock: ${a.stockActual}',
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        dense: true,
      ),
    );
  }

  // ── Valoración por categoría ──────────────────────────────────────
  Widget _buildValoracionSection(List<ValoracionCategoria> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.pie_chart_outline, color: AppColors.colReportes, size: 20),
          const SizedBox(width: 8),
          Text('Inventario por categoría', style: Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height: 10),
        if (items.isEmpty)
          _EmptyCard(icon: Icons.inventory_outlined, color: AppColors.textSecondary, text: 'Sin datos de inventario')
        else
          ...items.map((v) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.nombreCategoria, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text('${v.totalProductos} productos · ${v.totalUnidades} unidades',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  )),
                  Text(_currency.format(v.valorTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary)),
                ],
              ),
            ),
          )),
      ],
    );
  }

  // ── Control de hoy ────────────────────────────────────────────────
  Widget _buildControlHoySection(DashboardState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.today_outlined, color: AppColors.colControl, size: 20),
          const SizedBox(width: 8),
          Text('Control de hoy', style: Theme.of(context).textTheme.titleMedium),
        ]),
        const SizedBox(height: 10),
        if (state.controlHoy.isEmpty)
          _EmptyCard(icon: Icons.event_note_outlined, color: AppColors.textSecondary, text: 'Sin movimientos registrados hoy')
        else ...[
          Row(children: [
            Expanded(child: _MiniStatCard(label: 'Entradas', value: _currency.format(state.totalEntradaHoy), color: AppColors.colEntradas, icon: Icons.arrow_downward)),
            const SizedBox(width: 12),
            Expanded(child: _MiniStatCard(label: 'Salidas',  value: _currency.format(state.totalSalidaHoy),  color: AppColors.stockCero,  icon: Icons.arrow_upward)),
          ]),
          const SizedBox(height: 8),
          ...state.controlHoy.map((c) => Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(c.descripcion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              trailing: c.montoEntrada > 0
                  ? Text(_currency.format(c.montoEntrada), style: const TextStyle(color: AppColors.colEntradas, fontWeight: FontWeight.w700))
                  : Text('- ${_currency.format(c.montoSalida)}', style: const TextStyle(color: AppColors.stockCero, fontWeight: FontWeight.w700)),
            ),
          )),
        ],
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _SummaryCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Icon(icon, color: color, size: 22),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ],
    ),
  );
}

class _MiniStatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;
  const _MiniStatCard({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Row(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      ]),
    ]),
  );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;
  const _EmptyCard({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 20),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.15)),
    ),
    child: Column(children: [
      Icon(icon, color: color.withOpacity(0.5), size: 28),
      const SizedBox(height: 6),
      Text(text, style: TextStyle(fontSize: 13, color: color.withOpacity(0.7))),
    ]),
  );
}
