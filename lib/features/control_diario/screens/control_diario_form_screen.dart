import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../providers/control_diario_provider.dart';

/// P10a — Registrar Movimiento Diario. Scaffold propio (fuera del shell).
class ControlDiarioFormScreen extends ConsumerStatefulWidget {
  const ControlDiarioFormScreen({super.key});

  @override
  ConsumerState<ControlDiarioFormScreen> createState() =>
      _ControlDiarioFormScreenState();
}

class _ControlDiarioFormScreenState
    extends ConsumerState<ControlDiarioFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _descCtrl    = TextEditingController();
  final _entradaCtrl = TextEditingController(text: '0');
  final _salidaCtrl  = TextEditingController(text: '0');
  final _obsCtrl     = TextEditingController();
  final _dateFmt     = DateFormat('dd/MM/yyyy', 'es_MX');
  final _currency    = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  DateTime _fecha    = DateTime.now();
  bool     _esVerbena = false;
  String   _username  = '';

  double get _balance {
    final e = double.tryParse(_entradaCtrl.text) ?? 0;
    final s = double.tryParse(_salidaCtrl.text)  ?? 0;
    return e - s;
  }

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _username = p.getString(AppConstants.keyUsername) ?? '');
      }
    });
    _entradaCtrl.addListener(() => setState(() {}));
    _salidaCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _entradaCtrl.dispose();
    _salidaCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFecha() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) setState(() => _fecha = picked);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final body = {
      'fecha':           _fecha.toIso8601String().split('T').first,
      'descripcion':     _descCtrl.text.trim(),
      'monto_entrada':   double.tryParse(_entradaCtrl.text) ?? 0.0,
      'monto_salida':    double.tryParse(_salidaCtrl.text)  ?? 0.0,
      'observaciones':   _obsCtrl.text.trim(),
      'es_verbena':      _esVerbena,
      'usuario_registro': _username,
    };

    final ok = await ref.read(controlDiarioProvider.notifier).registrar(body);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Movimiento registrado'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    } else {
      final err = ref.read(controlDiarioProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error al registrar'),
        backgroundColor: AppColors.stockCero,
      ));
      ref.read(controlDiarioProvider.notifier).limpiarError();
    }
  }

  Future<void> _generarDesdeVentas() async {
    final fechaStr = _fecha.toIso8601String().split('T').first;
    final confirm  = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Generar desde ventas'),
        content: Text(
            'Se generará automáticamente el control del día '
            '${_dateFmt.format(_fecha)} a partir de las ventas registradas.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Generar')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await ref
        .read(controlDiarioProvider.notifier)
        .generarDesdeVentas(fechaStr);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Control generado desde ventas'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    } else {
      final err = ref.read(controlDiarioProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error al generar'),
        backgroundColor: AppColors.stockCero,
      ));
      ref.read(controlDiarioProvider.notifier).limpiarError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardando = ref.watch(controlDiarioProvider).guardando;
    final bal       = _balance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Registrar Movimiento'),
        actions: [
          TextButton.icon(
            onPressed: guardando ? null : _generarDesdeVentas,
            icon: const Icon(Icons.auto_fix_high, color: Colors.white70, size: 18),
            label: const Text('Desde ventas',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Fecha y descripción ───────────────────────────────────
                  _buildCard(
                    title: 'Detalle del movimiento',
                    icon: Icons.event_note_outlined,
                    color: AppColors.colControl,
                    children: [
                      // Fecha
                      InkWell(
                        onTap: _pickFecha,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_dateFmt.format(_fecha),
                                  style: const TextStyle(fontSize: 15)),
                              const Icon(Icons.arrow_drop_down,
                                  color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Descripción
                      TextFormField(
                        controller: _descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descripción *',
                          prefixIcon: Icon(Icons.description_outlined),
                          hintText: 'Ej: Ventas del día, gastos fijos…',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'La descripción es requerida'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      // Toggle Verbena
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: _esVerbena
                              ? AppColors.accent.withOpacity(0.1)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: _esVerbena
                                  ? AppColors.accent
                                  : const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.celebration,
                                color: _esVerbena
                                    ? AppColors.accent
                                    : AppColors.textHint,
                                size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Día de Verbena',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _esVerbena
                                              ? AppColors.accent
                                              : AppColors.textPrimary)),
                                  const Text('Activa si es un evento especial',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _esVerbena,
                              onChanged: (v) =>
                                  setState(() => _esVerbena = v),
                              activeColor: AppColors.accent,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Montos ────────────────────────────────────────────────
                  _buildCard(
                    title: 'Montos',
                    icon: Icons.account_balance_outlined,
                    color: AppColors.colControl,
                    children: [
                      // Monto entrada
                      TextFormField(
                        controller: _entradaCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Monto entrada',
                          prefixIcon: const Icon(Icons.arrow_downward_rounded,
                              color: AppColors.colEntradas),
                          filled: true,
                          fillColor: AppColors.colEntradas.withOpacity(0.04),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            if (double.tryParse(v) == null) return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Monto salida
                      TextFormField(
                        controller: _salidaCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                        ],
                        decoration: InputDecoration(
                          labelText: 'Monto salida',
                          prefixIcon: const Icon(Icons.arrow_upward_rounded,
                              color: AppColors.colSalidas),
                          filled: true,
                          fillColor: AppColors.colSalidas.withOpacity(0.04),
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            if (double.tryParse(v) == null) return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // Balance en tiempo real
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (bal >= 0
                                  ? AppColors.colEntradas
                                  : AppColors.stockCero)
                              .withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: (bal >= 0
                                      ? AppColors.colEntradas
                                      : AppColors.stockCero)
                                  .withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Balance del día',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: bal >= 0
                                        ? AppColors.colEntradas
                                        : AppColors.stockCero)),
                            Text(
                              (bal >= 0 ? '+' : '') + _currency.format(bal),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: bal >= 0
                                      ? AppColors.colEntradas
                                      : AppColors.stockCero),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Observaciones ──────────────────────────────────────────
                  _buildCard(
                    title: 'Observaciones',
                    icon: Icons.notes_outlined,
                    color: AppColors.textSecondary,
                    children: [
                      TextFormField(
                        controller: _obsCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Notas adicionales (opcional)…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── Guardar ───────────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colControl),
                      child: guardando
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text('Registrar movimiento',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String       title,
    required IconData     icon,
    required Color        color,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: color)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
