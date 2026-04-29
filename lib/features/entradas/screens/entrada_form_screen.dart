import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../providers/entradas_provider.dart';

/// P6 — Registrar Entrada. Pantalla completa con su propio Scaffold (fuera del shell).
class EntradaFormScreen extends ConsumerStatefulWidget {
  const EntradaFormScreen({super.key});

  @override
  ConsumerState<EntradaFormScreen> createState() => _EntradaFormScreenState();
}

class _EntradaFormScreenState extends ConsumerState<EntradaFormScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _cantCtrl    = TextEditingController(text: '1');
  final _precioCtrl  = TextEditingController();
  final _obsCtrl     = TextEditingController();
  final _dateFmt     = DateFormat('dd/MM/yyyy', 'es_MX');

  // Estado del buscador de producto
  final _searchCtrl  = TextEditingController();
  List<_ProductoLite> _resultados = [];
  _ProductoLite? _seleccionado;
  bool _buscando     = false;

  DateTime _fecha    = DateTime.now();
  String   _username = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _username = p.getString(AppConstants.keyUsername) ?? '');
    });
  }

  @override
  void dispose() {
    _cantCtrl.dispose();
    _precioCtrl.dispose();
    _obsCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Buscar producto por nombre/código ─────────────────────────────────────
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

    final precioText = _precioCtrl.text.trim();
    final body = {
      'id_producto':     _seleccionado!.id,
      'fecha_entrada':   _fecha.toIso8601String().split('T').first,
      'cantidad':        int.parse(_cantCtrl.text),
      'precio_unitario': precioText.isNotEmpty ? double.tryParse(precioText) : null,
      'observaciones':   _obsCtrl.text.trim(),
      'usuario_registro': _username,
    };

    final ok = await ref.read(entradasProvider.notifier).registrar(body);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Entrada registrada'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    } else {
      final err = ref.read(entradasProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Error al registrar'),
        backgroundColor: AppColors.stockCero,
      ));
      ref.read(entradasProvider.notifier).limpiarError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final guardando = ref.watch(entradasProvider).guardando;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Registrar Entrada')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Selector de producto ────────────────────────────────
                  _buildCard(title: 'Producto', icon: Icons.inventory_2_outlined, color: AppColors.colProductos, children: [
                    _buildProductoSearch(),
                    if (_seleccionado != null) ...[
                      const SizedBox(height: 10),
                      _buildProductoSeleccionado(),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // ── Cantidad y fecha ────────────────────────────────────
                  _buildCard(title: 'Detalle', icon: Icons.edit_note_outlined, color: AppColors.colEntradas, children: [
                    // Fecha
                    InkWell(
                      onTap: _pickFecha,
                      borderRadius: BorderRadius.circular(10),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha de entrada',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_dateFmt.format(_fecha),
                                style: const TextStyle(fontSize: 15)),
                            const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
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
                        prefixIcon: Icon(Icons.add_box_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final n = int.tryParse(v);
                        if (n == null || n < 1) return 'Mínimo 1';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Precio unitario (opcional)
                    TextFormField(
                      controller: _precioCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      decoration: const InputDecoration(
                        labelText: 'Precio de compra (opcional)',
                        prefixIcon: Icon(Icons.attach_money),
                        hintText: '0.00',
                        helperText: 'Déjalo vacío si no tienes el precio de compra',
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Observaciones ───────────────────────────────────────
                  _buildCard(title: 'Observaciones', icon: Icons.notes_outlined, color: AppColors.textSecondary, children: [
                    TextFormField(
                      controller: _obsCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Notas adicionales (opcional)…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 28),

                  // ── Botón guardar ───────────────────────────────────────
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: guardando ? null : _guardar,
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.colEntradas),
                      child: guardando
                          ? const SizedBox(width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Registrar entrada',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

  // ── Buscador de producto ──────────────────────────────────────────────────
  Widget _buildProductoSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (q) {
            if (_seleccionado != null) setState(() => _seleccionado = null);
            _buscarProducto(q);
          },
          decoration: InputDecoration(
            labelText: 'Buscar producto *',
            hintText: 'Código o nombre…',
            prefixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.colProductos)))
                : const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
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
                  leading: const Icon(Icons.diamond_outlined, size: 18, color: AppColors.colProductos),
                  title: Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text('${p.codigo} · Stock: ${p.stockActual}',
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
                Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${p.codigo} · Stock actual: ${p.stockActual}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String  title,
    required IconData icon,
    required Color   color,
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
              Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            ]),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Modelo local ligero (solo para el buscador) ───────────────────────────────

class _ProductoLite {
  final int    id;
  final String codigo;
  final String nombre;
  final int    stockActual;

  const _ProductoLite({required this.id, required this.codigo, required this.nombre, required this.stockActual});

  factory _ProductoLite.fromJson(Map<String, dynamic> j) => _ProductoLite(
    id:          j['id_producto']  as int,
    codigo:      j['codigo']       as String,
    nombre:      j['nombre']       as String,
    stockActual: j['stock_actual'] as int,
  );
}
