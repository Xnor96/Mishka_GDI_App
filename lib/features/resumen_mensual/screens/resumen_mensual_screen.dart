import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../models/resumen_mensual_models.dart';
import '../providers/resumen_mensual_provider.dart';

/// P10b — Resumen Mensual. Scaffold/AppBar los provee AppShell.
class ResumenMensualScreen extends ConsumerStatefulWidget {
  const ResumenMensualScreen({super.key});

  @override
  ConsumerState<ResumenMensualScreen> createState() =>
      _ResumenMensualScreenState();
}

class _ResumenMensualScreenState
    extends ConsumerState<ResumenMensualScreen> {
  final _currency = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Selector mes/año
  int _mes  = DateTime.now().month;
  int _anio = DateTime.now().year;

  // Formulario de generación manual
  final _ingresosCtrl  = TextEditingController();
  final _fijosCtrl     = TextEditingController();
  final _variablesCtrl = TextEditingController();
  final _obsCtrl       = TextEditingController();
  bool _showForm = false;

  static const _meses = [
    'Enero','Febrero','Marzo','Abril','Mayo','Junio',
    'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(resumenMensualProvider.notifier).cargarActual();
    });
  }

  @override
  void dispose() {
    _ingresosCtrl.dispose();
    _fijosCtrl.dispose();
    _variablesCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscarMes() async {
    await ref.read(resumenMensualProvider.notifier).cargarPorMes(_mes, _anio);
  }

  Future<void> _generarResumen() async {
    final body = {
      'mes':                   _mes,
      'anio':                  _anio,
      'total_ingresos':        double.tryParse(_ingresosCtrl.text)  ?? 0.0,
      'total_gastos_fijos':    double.tryParse(_fijosCtrl.text)     ?? 0.0,
      'total_gastos_variables':double.tryParse(_variablesCtrl.text) ?? 0.0,
      'observaciones':         _obsCtrl.text.trim(),
    };
    final ok = await ref.read(resumenMensualProvider.notifier).generar(body);
    if (!mounted) return;
    if (ok) {
      setState(() => _showForm = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Resumen generado'),
        backgroundColor: AppColors.stockOk,
      ));
    } else {
      final err = ref.read(resumenMensualProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error'),
        backgroundColor: AppColors.stockCero,
      ));
      ref.read(resumenMensualProvider.notifier).limpiarError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resumenMensualProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.error != null) _buildErrorBanner(state.error!),

              // ── Selector de mes/año ───────────────────────────────────────
              _buildSelectorMes(state),
              const SizedBox(height: 16),

              // ── Resumen actual ────────────────────────────────────────────
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)),
                )
              else if (state.actual != null)
                _buildResumenCard(state.actual!)
              else
                _buildSinResumen(),

              const SizedBox(height: 16),

              // ── Formulario de generación ──────────────────────────────────
              _buildFormSection(state),
            ],
          ),
        ),
      ),
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            onPressed: () =>
                ref.read(resumenMensualProvider.notifier).limpiarError(),
          ),
        ],
      ),
    );
  }

  // ── Selector ──────────────────────────────────────────────────────────────
  Widget _buildSelectorMes(ResumenMensualState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.search, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('Consultar mes',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                      color: AppColors.primary)),
            ]),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<int>(
                    value: _mes,
                    decoration: const InputDecoration(labelText: 'Mes'),
                    items: List.generate(12, (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text(_meses[i]))),
                    onChanged: (v) => setState(() => _mes = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _anio.toString(),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(labelText: 'Año'),
                    onChanged: (v) {
                      final n = int.tryParse(v);
                      if (n != null && n >= 2020) setState(() => _anio = n);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: state.isLoading ? null : _buscarMes,
                  child: const Text('Buscar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tarjeta de resumen ────────────────────────────────────────────────────
  Widget _buildResumenCard(ResumenMensual r) {
    final balPos = r.balance >= 0;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${r.nombreMes} ${r.anio}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  Text(
                      'Generado el ${DateFormat('dd/MM/yyyy', 'es_MX').format(r.fechaGeneracion)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ]),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: (balPos ? AppColors.colEntradas : AppColors.stockCero)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: (balPos
                                ? AppColors.colEntradas
                                : AppColors.stockCero)
                            .withOpacity(0.3)),
                  ),
                  child: Column(children: [
                    Text('Balance',
                        style: TextStyle(
                            fontSize: 11,
                            color: balPos
                                ? AppColors.colEntradas
                                : AppColors.stockCero)),
                    Text(
                        (balPos ? '+' : '') + _currency.format(r.balance),
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: balPos
                                ? AppColors.colEntradas
                                : AppColors.stockCero)),
                  ]),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),

            // Grid de montos
            _buildMontoRow('Ingresos totales', r.totalIngresos,
                Icons.arrow_downward_rounded, AppColors.colEntradas),
            const SizedBox(height: 12),
            _buildMontoRow('Gastos fijos', r.totalGastosFijos,
                Icons.arrow_upward_rounded, AppColors.colSalidas),
            const SizedBox(height: 12),
            _buildMontoRow('Gastos variables', r.totalGastosVariables,
                Icons.arrow_upward_rounded, AppColors.stockBajo),
            if (r.observaciones.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(r.observaciones,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMontoRow(
      String label, double monto, IconData icon, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ]),
        Text(_currency.format(monto),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }

  // ── Sin resumen ───────────────────────────────────────────────────────────
  Widget _buildSinResumen() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            const Text('Sin resumen para este periodo',
                style: TextStyle(
                    fontSize: 16, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            const Text(
                'Puedes generarlo automáticamente desde los datos de ventas,\n'
                'o ingresar los montos manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  // ── Formulario generar ────────────────────────────────────────────────────
  Widget _buildFormSection(ResumenMensualState state) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _showForm = !_showForm),
                icon: Icon(_showForm ? Icons.expand_less : Icons.add),
                label: Text(_showForm ? 'Ocultar formulario' : 'Generar / Actualizar resumen'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        if (_showForm) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [
                    Icon(Icons.auto_fix_high,
                        color: AppColors.primary, size: 18),
                    SizedBox(width: 8),
                    Text('Generar resumen',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppColors.primary)),
                  ]),
                  const SizedBox(height: 6),
                  const Text(
                      'Deja los montos en 0 para calcular automáticamente '
                      'desde las ventas del período.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 16),
                  _montoField(_ingresosCtrl, 'Ingresos totales',
                      AppColors.colEntradas),
                  const SizedBox(height: 12),
                  _montoField(
                      _fijosCtrl, 'Gastos fijos', AppColors.colSalidas),
                  const SizedBox(height: 12),
                  _montoField(_variablesCtrl, 'Gastos variables',
                      AppColors.stockBajo),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _obsCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: state.generando ? null : _generarResumen,
                      icon: state.generando
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_circle_outline,
                              color: Colors.white, size: 18),
                      label: Text(state.generando
                          ? 'Generando…'
                          : 'Guardar resumen ${_meses[_mes - 1]} $_anio'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _montoField(
      TextEditingController ctrl, String label, Color color) {
    return TextFormField(
      controller: ctrl,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
      ],
      decoration: InputDecoration(
        labelText: label,
        hintText: '0.00',
        prefixIcon: Icon(Icons.attach_money, color: color, size: 18),
      ),
    );
  }
}
