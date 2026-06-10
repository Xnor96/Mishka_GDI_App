import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/productos_provider.dart';
import '../models/producto_models.dart';

/// Pantalla dual: ver/editar producto existente O crear uno nuevo.
/// Si [producto] es null → modo CREAR.
class ProductoFormScreen extends ConsumerStatefulWidget {
  final Producto? producto;
  const ProductoFormScreen({super.key, this.producto});

  @override
  ConsumerState<ProductoFormScreen> createState() => _ProductoFormScreenState();
}

class _ProductoFormScreenState extends ConsumerState<ProductoFormScreen> {
  static const Map<int, String> _cats = {
    1: 'ANILLO', 2: 'ARETE', 3: 'COLLAR',
    4: 'JUEGO',  5: 'OTRO',  6: 'PULSERA',
  };

  final _formKey = GlobalKey<FormState>();

  late final _codigoCtrl  = TextEditingController();
  late final _nombreCtrl  = TextEditingController();
  late final _precioCtrl  = TextEditingController();
  late final _stockActCtrl  = TextEditingController();
  late final _stockIniCtrl  = TextEditingController();
  late final _unidadCtrl  = TextEditingController();

  int?   _idCategoria;
  bool   _modoEdicion = false;
  bool   _guardando   = false;

  bool get _esNuevo => widget.producto == null;

  @override
  void initState() {
    super.initState();
    _modoEdicion = _esNuevo;
    if (!_esNuevo) _poblarCampos(widget.producto!);
  }

  void _poblarCampos(Producto p) {
    _codigoCtrl.text   = p.codigo;
    _nombreCtrl.text   = p.nombre;
    _precioCtrl.text   = p.precioUnitario.toStringAsFixed(2);
    _stockActCtrl.text = p.stockActual.toString();
    _stockIniCtrl.text = p.stockInicial.toString();
    _unidadCtrl.text   = p.unidadMedida;
    _idCategoria       = p.idCategoria;
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _precioCtrl.dispose();
    _stockActCtrl.dispose();
    _stockIniCtrl.dispose();
    _unidadCtrl.dispose();
    super.dispose();
  }

  // ── Guardar ─────────────────────────────────────────────────────────────────
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);

    final body = {
      'codigo':          _codigoCtrl.text.trim(),
      'nombre':          _nombreCtrl.text.trim(),
      'id_categoria':    _idCategoria,
      'unidad_medida':   _unidadCtrl.text.trim(),
      'precio_unitario': double.tryParse(_precioCtrl.text) ?? 0.0,
      'stock_actual':    int.tryParse(_stockActCtrl.text) ?? 0,
      'stock_inicial':   int.tryParse(_stockIniCtrl.text) ?? 0,
    };

    final ok = _esNuevo
        ? await ref.read(productosProvider.notifier).crear(body)
        : await ref.read(productosProvider.notifier)
            .actualizar(widget.producto!.id, body);

    setState(() => _guardando = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_esNuevo ? 'Producto creado' : 'Producto actualizado'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    } else {
      final err = ref.read(productosProvider).error;
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: AppColors.stockCero,
        ));
        ref.read(productosProvider.notifier).limpiarError();
      }
    }
  }

  // ── Eliminar ─────────────────────────────────────────────────────────────────
  Future<void> _eliminar() async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "${widget.producto!.nombre}"?\nEsta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.stockCero),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirma != true || !mounted) return;

    setState(() => _guardando = true);
    final ok = await ref.read(productosProvider.notifier).eliminar(widget.producto!.id);
    setState(() => _guardando = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Producto eliminado'),
        backgroundColor: AppColors.stockOk,
      ));
      context.pop();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final title = _esNuevo
        ? 'Nuevo producto'
        : _modoEdicion ? 'Editar producto' : widget.producto!.nombre;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (!_esNuevo && !_modoEdicion) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: () => setState(() => _modoEdicion = true),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Eliminar',
              onPressed: _eliminar,
            ),
          ],
          if (_modoEdicion && !_esNuevo)
            TextButton(
              onPressed: () {
                setState(() => _modoEdicion = false);
                _poblarCampos(widget.producto!);
              },
              child: const Text('Cancelar', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
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
                  // ── Header (solo en modo vista) ─────────────────────────
                  if (!_modoEdicion && !_esNuevo)
                    _buildHeader(widget.producto!),

                  // ── Campos ──────────────────────────────────────────────
                  _buildCard(children: [
                    _field(
                      ctrl:  _codigoCtrl,
                      label: 'Código',
                      icon:  Icons.qr_code,
                      hint:   'Ej. ANL-001',
                      required: true,
                      enabled: _modoEdicion,
                      inputFormatters: [UpperCaseFormatter()],
                    ),
                    const SizedBox(height: 16),
                    _field(
                      ctrl:  _nombreCtrl,
                      label: 'Nombre',
                      icon:  Icons.label_outline,
                      hint:  'Nombre descriptivo del producto',
                      required: true,
                      enabled: _modoEdicion,
                    ),
                    const SizedBox(height: 16),
                    // Dropdown categoría
                    _buildCategoriaDropdown(),
                    const SizedBox(height: 16),
                    _field(
                      ctrl:  _unidadCtrl,
                      label: 'Unidad de medida',
                      icon:  Icons.straighten,
                      hint:  'Ej. PZA, PAR, JGO',
                      enabled: _modoEdicion,
                      inputFormatters: [UpperCaseFormatter()],
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _buildCard(children: [
                    _field(
                      ctrl:  _precioCtrl,
                      label: 'Precio unitario',
                      icon:  Icons.attach_money,
                      hint:  '0.00',
                      required: true,
                      enabled: _modoEdicion,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        final n = double.tryParse(v);
                        if (n == null || n < 0) return 'Precio inválido';
                        return null;
                      },
                    ),
                  ]),
                  const SizedBox(height: 16),

                  _buildCard(children: [
                    _field(
                      ctrl:  _stockIniCtrl,
                      label: 'Stock inicial',
                      icon:  Icons.inventory_2_outlined,
                      hint:  '0',
                      enabled: _modoEdicion,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 16),
                    _field(
                      ctrl:  _stockActCtrl,
                      label: 'Stock actual',
                      icon:  Icons.warehouse_outlined,
                      hint:  '0',
                      enabled: _modoEdicion,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ]),

                  // ── Botón guardar ───────────────────────────────────────
                  if (_modoEdicion) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _guardando ? null : _guardar,
                        child: _guardando
                            ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(_esNuevo ? 'Crear producto' : 'Guardar cambios'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets auxiliares ───────────────────────────────────────────────────────

  Widget _buildHeader(Producto p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.colProductos, Color(0xFF1976D2)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.diamond_outlined, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.codigo,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(p.nombre,
                  style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 16),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          _StockChip(stock: p.stockActual),
        ],
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController ctrl,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    bool enabled = true,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: validator ??
          (required
              ? (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null
              : null),
    );
  }

  Widget _buildCategoriaDropdown() {
    return DropdownButtonFormField<int>(
      value: _idCategoria,
      decoration: const InputDecoration(
        labelText: 'Categoría',
        prefixIcon: Icon(Icons.category_outlined),
      ),
      items: [
        const DropdownMenuItem<int>(
          value: null,
          child: Text('Sin categoría', style: TextStyle(color: AppColors.textHint)),
        ),
        ..._cats.entries.map((e) =>
          DropdownMenuItem<int>(value: e.key, child: Text(e.value))),
      ],
      onChanged: _modoEdicion ? (v) => setState(() => _idCategoria = v) : null,
    );
  }
}

// ── Stock chip (en header) ────────────────────────────────────────────────────

class _StockChip extends StatelessWidget {
  final int stock;
  const _StockChip({required this.stock});

  @override
  Widget build(BuildContext context) {
    final color = stock == 0
        ? AppColors.stockCero
        : stock <= 3 ? AppColors.stockBajo : AppColors.stockOk;
    final label = stock == 0 ? 'Sin stock' : 'Stock: $stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.7)),
      ),
      child: Text(label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

// ── Formatter: fuerza mayúsculas ──────────────────────────────────────────────

class UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
