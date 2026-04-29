import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../providers/salidas_provider.dart';

/// P8 — Registrar Venta. Pantalla completa con su propio Scaffold (fuera del shell).
class SalidaFormScreen extends ConsumerStatefulWidget {
  const SalidaFormScreen({super.key});

  @override
  ConsumerState<SalidaFormScreen> createState() => _SalidaFormScreenState();
}

class _SalidaFormScreenState extends ConsumerState<SalidaFormScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _cantCtrl   = TextEditingController(text: '1');
  final _precioCtrl = TextEditingController();
  final _descCtrl   = TextEditingController(text: '0');
  final _obsCtrl    = TextEditingController();
  final _dateFmt    = DateFormat('dd/MM/yyyy', 'es_MX');
  final _currency   = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Buscador de producto
  final _searchCtrl = TextEditingController();
  List<_ProductoLite> _resultados = [];
  _ProductoLite? _seleccionado;
  bool _buscando    = false;

  DateTime _fecha   = DateTime.now();
  String _username  = '';
  String _lugarVenta = 'ALL BAZAR';
  String _tipoPago   = 'EFECTIVO';

  // Total calculado en tiempo real
  double get _total {
    final cant   = double.tryParse(_cantCtrl.text)   ?? 0;
    final precio = double.tryParse(_precioCtrl.text) ?? 0;
    final desc   = double.tryParse(_descCtrl.text)   ?? 0;
    return (cant * precio - desc).clamp(0, double.infinity);
  }

  static const _lugares = ['ALL BAZAR', 'PINKSTORE', 'PERSONAL', 'OTRO'];
  static const _pagos   = ['EFECTIVO', 'TRANSFERENCIA', 'CLIP', 'OTRO'];

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() => _username = p.getString(AppConstants.keyUsername) ?? '');
      }
    });
    // Recalcular total al cambiar campos
    _cantCtrl.addListener(() => setState(() {}));
    _precioCtrl.addListener(() => setState(() {}));
    _descCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    _descCtrl.dispose();
    _obsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Buscar producto ───────────────────────────────────────────────────────
  Future<void> _buscarProducto(String q) async {
    if (q.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final res = await ApiClient.instance
          .get('/api/productos/buscar', queryParameters: {'q': q.trim()});
      final lista = (res.data['data'] as List)
          .map((j) => _ProductoLite.fromJson(j as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() { _resultados = lista; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _seleccionarProducto(_ProductoLite p) {
    setState(() {
      _seleccionado = p;
      _searchCtrl.text = '${p.codigo} — ${p.nombre}';
      _resultados = [];
      // Pre-llenar precio de venta si el producto tiene precio
      if (p.precioUnitario > 0 && _precioCtrl.text.isEmpty) {
        _precioCtrl.text = p.precioUnitario.toStringAsFixed(2);
      }
    });
  }

  // ── Selector de fecha ─────────────────────────────────────────────────────
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

  // ── Guardar ───────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_seleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecciona un producto'),
        backgroundColor: AppColors.stockCero,
      ));
      return;
    }

    final body = {
      'id_producto':      _seleccionado!.id,
      'fecha_salida':     _fecha.toIso8601String().split('T').first,
      'cantidad':         int.parse(_cantCtrl.text),
      'precio_venta':     double.tryParse(_precioCtrl.text) ?? 0.0,
      'descuento':        double.tryParse(_descCtrl.text)   ?? 0.0,
      'lugar_venta':      _lugarVenta,
      'tipo_pago':        _tipoPago,
      'observaciones':    _obsCtrl.text.trim(),
      'usuario_registro': _username,
    };

    final ok = await ref.read(salidasProvider.notifier).registrar(body);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Venta registrada'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    } else {
      final err = ref.read(salidasProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error al registrar'),
        backgroundColor: AppColors.stockCero,
      ));
      ref.read(salidasProvider.notifier).limpiarError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardando = ref.watch(salidasProvider).guardando;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Registrar Venta')),
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
                  // ── Producto ─────────────────────────────────────────────
                  _buildCard(
                    title: 'Producto',
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.colProductos,
                    children: [
                      _buildProductoSearch(),
                      if (_seleccionado != null) ...[
                        const SizedBox(height: 10),
                        _buildProductoSeleccionado(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Detalle de venta ──────────────────────────────────────
                  _buildCard(
                    title: 'Detalle de Venta',
                    icon: Icons.point_of_sale_outlined,
                    color: AppColors.colSalidas,
                    children: [
                      // Fecha
                      InkWell(
                        onTap: _pickFecha,
                        borderRadius: BorderRadius.circular(10),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Fecha de venta',
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

                      // Cantidad
                      TextFormField(
                        controller: _cantCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Cantidad *',
                          prefixIcon: Icon(Icons.remove_circle_outline),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = int.tryParse(v);
                          if (n == null || n < 1) return 'Mínimo 1';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Precio de venta
                      TextFormField(
                        controller: _precioCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Precio de venta *',
                          prefixIcon: Icon(Icons.attach_money),
                          hintText: '0.00',
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Requerido';
                          final n = double.tryParse(v);
                          if (n == null || n < 0) return 'Ingresa un precio válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Descuento
                      TextFormField(
                        controller: _descCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Descuento',
                          prefixIcon: Icon(Icons.discount_outlined),
                          hintText: '0.00',
                          helperText: 'Monto fijo a descontar del total',
                        ),
                        validator: (v) {
                          if (v != null && v.isNotEmpty) {
                            final n = double.tryParse(v);
                            if (n == null || n < 0) return 'Valor inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Total en tiempo real
                      _buildTotalCard(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Punto de venta y tipo de pago ─────────────────────────
                  _buildCard(
                    title: 'Punto de Venta',
                    icon: Icons.store_outlined,
                    color: AppColors.colControl,
                    children: [
                      // Lugar de venta
                      DropdownButtonFormField<String>(
                        value: _lugarVenta,
                        decoration: const InputDecoration(
                          labelText: 'Lugar de venta',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        items: _lugares
                            .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                            .toList(),
                        onChanged: (v) => setState(() => _lugarVenta = v!),
                      ),
                      const SizedBox(height: 16),

                      // Tipo de pago
                      DropdownButtonFormField<String>(
                        value: _tipoPago,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de pago',
                          prefixIcon: Icon(Icons.payment_outlined),
                        ),
                        items: _pagos
                            .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                            .toList(),
                        onChanged: (v) => setState(() => _tipoPago = v!),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Observaciones ─────────────────────────────────────────
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

                  // ── Botón guardar ──────────────────────────────────────────
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.colSalidas),
                      child: guardando
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_outline,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Registrar venta  ·  ${_currency.format(_total)}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700),
                                ),
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

  // ── Total en tiempo real ──────────────────────────────────────────────────
  Widget _buildTotalCard() {
    final cant    = double.tryParse(_cantCtrl.text)   ?? 0;
    final precio  = double.tryParse(_precioCtrl.text) ?? 0;
    final desc    = double.tryParse(_descCtrl.text)   ?? 0;
    final subtotal = cant * precio;
    final total   = (subtotal - desc).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.colSalidas.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colSalidas.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Subtotal', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            Text(_currency.format(subtotal),
                style: const TextStyle(fontSize: 13)),
          ]),
          if (desc > 0) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Descuento', style: TextStyle(fontSize: 13, color: AppColors.stockBajo)),
              Text('−${_currency.format(desc)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.stockBajo)),
            ]),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('TOTAL',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.colSalidas)),
            Text(_currency.format(total),
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.colSalidas)),
          ]),
        ],
      ),
    );
  }

  // ── Buscador de producto ──────────────────────────────────────────────────
  Widget _buildProductoSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (q) {
            if (_seleccionado != null) {
              setState(() { _seleccionado = null; _precioCtrl.clear(); });
            }
            _buscarProducto(q);
          },
          decoration: InputDecoration(
            labelText: 'Buscar producto *',
            hintText: 'Código o nombre…',
            prefixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.colProductos)))
                : const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      _precioCtrl.clear();
                      setState(() { _resultados = []; _seleccionado = null; });
                    })
                : null,
          ),
        ),
        if (_resultados.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E0E0)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06), blurRadius: 8)
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _resultados.length > 6 ? 6 : _resultados.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = _resultados[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.diamond_outlined,
                      size: 18, color: AppColors.colProductos),
                  title: Text(p.nombre,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${p.codigo} · Stock: ${p.stockActual}'
                      '${p.precioUnitario > 0 ? ' · P: \$${p.precioUnitario.toStringAsFixed(2)}' : ''}',
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => _seleccionarProducto(p),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductoSeleccionado() {
    final p = _seleccionado!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.colProductos.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.colProductos.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.stockOk, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(
                    '${p.codigo} · Stock: ${p.stockActual}'
                    '${p.precioUnitario > 0 ? ' · Precio ref: \$${p.precioUnitario.toStringAsFixed(2)}' : ''}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
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

// ── Modelo local ligero ───────────────────────────────────────────────────────

class _ProductoLite {
  final int    id;
  final String codigo;
  final String nombre;
  final int    stockActual;
  final double precioUnitario;

  const _ProductoLite({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.stockActual,
    required this.precioUnitario,
  });

  factory _ProductoLite.fromJson(Map<String, dynamic> j) => _ProductoLite(
    id:             j['id_producto']    as int,
    codigo:         j['codigo']         as String,
    nombre:         j['nombre']         as String,
    stockActual:    j['stock_actual']   as int,
    precioUnitario: (j['precio_unitario'] as num? ?? 0).toDouble(),
  );
}
