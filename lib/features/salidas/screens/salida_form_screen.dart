import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/dao/producto_dao.dart';
import '../models/salida_models.dart';
import '../providers/salidas_provider.dart';

/// P8 — Registrar Venta multi-ítem (carrito).
/// Pantalla completa con su propio Scaffold (fuera del shell).
class SalidaFormScreen extends ConsumerStatefulWidget {
  const SalidaFormScreen({super.key});

  @override
  ConsumerState<SalidaFormScreen> createState() => _SalidaFormScreenState();
}

class _SalidaFormScreenState extends ConsumerState<SalidaFormScreen> {
  final _dateFmt    = DateFormat('dd/MM/yyyy', 'es_MX');
  final _currency   = NumberFormat.currency(locale: 'es_MX', symbol: '\$');

  // Buscador de producto
  final _searchCtrl = TextEditingController();
  List<_ProductoLite> _resultados = [];
  bool _buscando    = false;

  // Carrito (líneas pendientes de confirmar)
  final List<LineaCarrito> _carrito = [];

  // Header de la venta
  DateTime _fecha   = DateTime.now();
  String _username  = '';
  final _lugarCtrl  = TextEditingController();
  List<String> _lugaresSugeridos = [];
  String _tipoPago   = 'EFECTIVO';
  final _obsCtrl    = TextEditingController();

  static const _lugaresBase = ['ALL BAZAR', 'PINKSTORE', 'PERSONAL', 'OTRO'];
  static const _pagos       = ['EFECTIVO', 'TRANSFERENCIA', 'CLIP', 'OTRO'];

  double get _totalVenta =>
      _carrito.fold<double>(0, (s, l) => s + l.subtotal);

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      final custom = p.getStringList(AppConstants.keyLugaresCustom) ?? [];
      // Prioridad: filtro actual > último usado > base
      final filtro = p.getString(AppConstants.keyFiltroLugar);
      final ultimoLugar = filtro
          ?? p.getString(AppConstants.keyUltimoLugar)
          ?? _lugaresBase.first;
      final ultimoPago  = p.getString(AppConstants.keyUltimoPago)
          ?? _pagos.first;
      setState(() {
        _username = p.getString(AppConstants.keyUsername) ?? '';
        _lugarCtrl.text = ultimoLugar;
        _tipoPago = _pagos.contains(ultimoPago) ? ultimoPago : _pagos.first;
        _lugaresSugeridos = [
          ..._lugaresBase,
          ...custom.where((l) => !_lugaresBase.contains(l)),
        ];
        if (!_lugaresSugeridos.contains(ultimoLugar)) {
          _lugaresSugeridos = [..._lugaresSugeridos, ultimoLugar];
        }
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _lugarCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  // ── Persistir lugar nuevo si no existía ────────────────────────────────────
  Future<void> _persistirLugarSiEsNuevo(String lugar) async {
    final l = lugar.trim();
    if (l.isEmpty || _lugaresSugeridos.contains(l)) return;
    final p = await SharedPreferences.getInstance();
    final custom = p.getStringList(AppConstants.keyLugaresCustom) ?? [];
    if (!custom.contains(l)) {
      custom.add(l);
      await p.setStringList(AppConstants.keyLugaresCustom, custom);
    }
  }

  // ── Elegir lugar de venta (bottom sheet) ──────────────────────────────────
  Future<void> _elegirLugar() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        color: AppColors.colSalidas, size: 20),
                    const SizedBox(width: 8),
                    const Text('Lugar de venta',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final l in _lugaresSugeridos)
                      ListTile(
                        leading: Icon(
                          _lugarCtrl.text == l
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _lugarCtrl.text == l
                              ? AppColors.colSalidas
                              : AppColors.textHint,
                          size: 20,
                        ),
                        title: Text(l,
                            style: TextStyle(
                                fontWeight: _lugarCtrl.text == l
                                    ? FontWeight.w700
                                    : FontWeight.normal)),
                        onTap: () => Navigator.pop(ctx, l),
                      ),
                    const Divider(height: 8),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline,
                          color: AppColors.primary),
                      title: const Text('Agregar lugar nuevo…',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic)),
                      onTap: () => Navigator.pop(ctx, '__nuevo__'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (sel == null) return;
    if (sel == '__nuevo__') {
      await _agregarLugarNuevo();
    } else {
      setState(() => _lugarCtrl.text = sel);
    }
  }

  // ── Elegir tipo de pago (bottom sheet) ────────────────────────────────────
  Future<void> _elegirTipoPago() async {
    final sel = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        IconData iconFor(String tipo) {
          switch (tipo) {
            case 'EFECTIVO':      return Icons.payments_outlined;
            case 'TRANSFERENCIA': return Icons.account_balance_outlined;
            case 'CLIP':          return Icons.credit_card_outlined;
            default:              return Icons.payment_outlined;
          }
        }

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Row(
                  children: [
                    const Icon(Icons.payment_outlined,
                        color: AppColors.colSalidas, size: 20),
                    const SizedBox(width: 8),
                    const Text('Tipo de pago',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    for (final p in _pagos)
                      ListTile(
                        leading: Icon(iconFor(p),
                            color: _tipoPago == p
                                ? AppColors.colSalidas
                                : AppColors.textSecondary),
                        trailing: _tipoPago == p
                            ? const Icon(Icons.check,
                                color: AppColors.colSalidas, size: 20)
                            : null,
                        title: Text(p,
                            style: TextStyle(
                                fontWeight: _tipoPago == p
                                    ? FontWeight.w700
                                    : FontWeight.normal)),
                        onTap: () => Navigator.pop(ctx, p),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
    if (sel != null) setState(() => _tipoPago = sel);
  }

  // ── Campo visual tipo "selector" (parece un input, abre bottom sheet) ─────
  Widget _buildSelectorCampo({
    required String   label,
    required IconData icon,
    required String   valor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                valor.isEmpty ? '—' : valor,
                style: TextStyle(
                  fontSize: 15,
                  color: valor.isEmpty
                      ? AppColors.textHint
                      : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Future<void> _agregarLugarNuevo() async {
    final ctrl = TextEditingController();
    final nuevo = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Nuevo lugar de venta'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Nombre del lugar',
            hintText: 'Ej. VERBENA, TIANGUIS, etc.',
          ),
          onSubmitted: (v) =>
              Navigator.pop(dialogCtx, v.trim().toUpperCase()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogCtx, ctrl.text.trim().toUpperCase()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (nuevo == null || nuevo.isEmpty) return;
    await _persistirLugarSiEsNuevo(nuevo);
    if (!mounted) return;
    setState(() {
      if (!_lugaresSugeridos.contains(nuevo)) {
        _lugaresSugeridos = [..._lugaresSugeridos, nuevo];
      }
      _lugarCtrl.text = nuevo;
    });
  }

  // ── Buscar producto ────────────────────────────────────────────────────────
  Future<void> _buscarProducto(String q) async {
    if (q.trim().length < 2) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      final rows = await ProductoDao().buscar(q.trim());
      final lista = rows.map((j) => _ProductoLite.fromJson(j)).toList();
      if (mounted) setState(() { _resultados = lista; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  // ── Agregar al carrito ─────────────────────────────────────────────────────
  void _agregarAlCarrito(_ProductoLite p) {
    // Si ya está en el carrito, sumá 1 a la cantidad (si hay stock)
    final existente = _carrito.indexWhere((l) => l.idProducto == p.id);
    setState(() {
      if (existente >= 0) {
        final linea = _carrito[existente];
        if (linea.cantidad < p.stockActual) {
          linea.cantidad += 1;
        } else {
          _mostrarMensaje(
              'No hay más stock de "${p.nombre}" (máx ${p.stockActual})',
              esError: true);
        }
      } else {
        if (p.stockActual <= 0) {
          _mostrarMensaje('"${p.nombre}" no tiene stock', esError: true);
        } else {
          _carrito.add(LineaCarrito(
            idProducto:      p.id,
            codigo:          p.codigo,
            nombre:          p.nombre,
            categoria:       p.categoria,
            stockDisponible: p.stockActual,
            cantidad:        1,
            precioUnitario:  p.precioUnitario,
          ));
        }
      }
      _searchCtrl.clear();
      _resultados = [];
    });
  }

  void _quitarDelCarrito(int idx) =>
      setState(() => _carrito.removeAt(idx));

  // ── Selector de fecha ──────────────────────────────────────────────────────
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

  // ── Confirmar venta ────────────────────────────────────────────────────────
  Future<void> _confirmar() async {
    if (_carrito.isEmpty) {
      _mostrarMensaje('Agregá al menos un producto', esError: true);
      return;
    }
    final lugar = _lugarCtrl.text.trim().toUpperCase();
    if (lugar.isEmpty) {
      _mostrarMensaje('Falta el lugar de venta', esError: true);
      return;
    }

    final fechaStr = _fecha.toIso8601String().split('T').first;
    final header = {
      'fecha_venta':      fechaStr,
      'lugar_venta':      lugar,
      'tipo_pago':        _tipoPago,
      'observaciones':    _obsCtrl.text.trim(),
      'usuario_registro': _username,
    };
    final lineas = _carrito.map((l) => {
      'id_producto':  l.idProducto,
      'cantidad':     l.cantidad,
      'precio_venta': l.precioUnitario,
    }).toList();

    // Memorizar lugar/pago para próxima venta
    await _persistirLugarSiEsNuevo(lugar);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyUltimoLugar, lugar);
    await prefs.setString(AppConstants.keyUltimoPago,  _tipoPago);

    final ok = await ref.read(salidasProvider.notifier).registrar(header, lineas);
    if (!mounted) return;
    if (ok) {
      _mostrarMensaje('Venta registrada');
      context.pop();
    } else {
      final err = ref.read(salidasProvider).error;
      _mostrarMensaje(err ?? 'Error al registrar la venta', esError: true);
      ref.read(salidasProvider.notifier).limpiarError();
    }
  }

  void _mostrarMensaje(String texto, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(texto),
      backgroundColor: esError ? AppColors.stockCero : AppColors.stockOk,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final guardando = ref.watch(salidasProvider).guardando;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nueva Venta')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Carrito (buscador + líneas) ───────────────────────────
                _buildCard(
                  title: 'Productos de la venta',
                  icon: Icons.shopping_cart_outlined,
                  color: AppColors.colSalidas,
                  children: [
                    _buildBuscador(),
                    const SizedBox(height: 14),
                    if (_carrito.isEmpty)
                      _buildCarritoVacio()
                    else ...[
                      ..._carrito.asMap().entries.map(
                        (e) => _buildLineaCarrito(e.key, e.value),
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.colSalidas)),
                          Text(_currency.format(_totalVenta),
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.colSalidas)),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // ── Detalle de la venta ───────────────────────────────────
                _buildCard(
                  title: 'Detalle',
                  icon: Icons.store_outlined,
                  color: AppColors.colControl,
                  children: [
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
                    // Lugar — DropdownMenu Material 3 (abre siempre debajo del campo)
                    LayoutBuilder(builder: (ctx, c) {
                      return DropdownMenu<String>(
                        width: c.maxWidth,
                        requestFocusOnTap: false,
                        enableFilter: false,
                        initialSelection:
                            _lugaresSugeridos.contains(_lugarCtrl.text)
                                ? _lugarCtrl.text
                                : null,
                        label: const Text('Lugar de venta'),
                        leadingIcon:
                            const Icon(Icons.location_on_outlined),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        menuStyle: MenuStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        dropdownMenuEntries: [
                          for (final l in _lugaresSugeridos)
                            DropdownMenuEntry(value: l, label: l),
                          const DropdownMenuEntry(
                            value: '__nuevo__',
                            label: 'Agregar lugar nuevo…',
                            leadingIcon: Icon(Icons.add_circle_outline,
                                size: 18, color: AppColors.primary),
                            style: ButtonStyle(
                              foregroundColor: WidgetStatePropertyAll(
                                  AppColors.primary),
                            ),
                          ),
                        ],
                        onSelected: (v) {
                          if (v == null) return;
                          if (v == '__nuevo__') {
                            _agregarLugarNuevo();
                          } else {
                            setState(() => _lugarCtrl.text = v);
                          }
                        },
                      );
                    }),
                    const SizedBox(height: 16),
                    // Tipo de pago — DropdownMenu Material 3
                    LayoutBuilder(builder: (ctx, c) {
                      IconData iconFor(String tipo) {
                        switch (tipo) {
                          case 'EFECTIVO':      return Icons.payments_outlined;
                          case 'TRANSFERENCIA': return Icons.account_balance_outlined;
                          case 'CLIP':          return Icons.credit_card_outlined;
                          default:              return Icons.payment_outlined;
                        }
                      }

                      return DropdownMenu<String>(
                        width: c.maxWidth,
                        requestFocusOnTap: false,
                        enableFilter: false,
                        initialSelection: _tipoPago,
                        label: const Text('Tipo de pago'),
                        leadingIcon: const Icon(Icons.payment_outlined),
                        inputDecorationTheme: const InputDecorationTheme(
                          border: OutlineInputBorder(),
                          filled: true,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        menuStyle: MenuStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        dropdownMenuEntries: [
                          for (final p in _pagos)
                            DropdownMenuEntry(
                              value: p,
                              label: p,
                              leadingIcon: Icon(iconFor(p), size: 18),
                            ),
                        ],
                        onSelected: (v) {
                          if (v != null) setState(() => _tipoPago = v);
                        },
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Observaciones ────────────────────────────────────────
                _buildCard(
                  title: 'Observaciones',
                  icon: Icons.notes_outlined,
                  color: AppColors.textSecondary,
                  children: [
                    TextField(
                      controller: _obsCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Notas (opcional)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Botón confirmar ───────────────────────────────────────
                SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: guardando || _carrito.isEmpty ? null : _confirmar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.colSalidas,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.colSalidas.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: guardando
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5, color: Colors.white))
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline),
                              const SizedBox(width: 10),
                              Text(
                                'Confirmar venta  ·  ${_currency.format(_totalVenta)}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
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
    );
  }

  // ── Widgets de ayuda ───────────────────────────────────────────────────────
  Widget _buildBuscador() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _searchCtrl,
          onChanged: _buscarProducto,
          decoration: InputDecoration(
            labelText: 'Buscar producto',
            hintText: 'Código o nombre…',
            prefixIcon: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.colSalidas)))
                : const Icon(Icons.search),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _resultados = []);
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
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _resultados.length > 6 ? 6 : _resultados.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = _resultados[i];
                final sinStock = p.stockActual <= 0;
                return ListTile(
                  dense: true,
                  enabled: !sinStock,
                  leading: Icon(Icons.add_shopping_cart,
                      size: 18,
                      color: sinStock ? AppColors.textHint : AppColors.colSalidas),
                  title: Text(p.nombre,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: sinStock ? AppColors.textHint : null)),
                  subtitle: Text(
                      '${p.codigo} · Stock: ${p.stockActual}'
                      '${p.precioUnitario > 0 ? ' · \$${p.precioUnitario.toStringAsFixed(2)}' : ''}',
                      style: const TextStyle(fontSize: 11)),
                  onTap: sinStock ? null : () => _agregarAlCarrito(p),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCarritoVacio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 36, color: Colors.grey.shade300),
          const SizedBox(height: 6),
          const Text('Aún no agregaste productos',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          const Text('Buscá arriba y tocá un producto para agregarlo',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _buildLineaCarrito(int idx, LineaCarrito l) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.nombre,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                    Text('${l.codigo} · stock: ${l.stockDisponible}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.stockCero, size: 20),
                tooltip: 'Quitar',
                onPressed: () => _quitarDelCarrito(idx),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              // Cantidad con − / +
              _buildStepper(
                value: l.cantidad,
                min: 1,
                max: l.stockDisponible,
                onChanged: (v) => setState(() => l.cantidad = v),
              ),
              const SizedBox(width: 10),
              // Precio editable
              SizedBox(
                width: 110,
                child: TextFormField(
                  initialValue: l.precioUnitario.toStringAsFixed(2),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                  ],
                  textAlign: TextAlign.right,
                  decoration: const InputDecoration(
                    labelText: 'Precio',
                    prefixText: '\$',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                  onChanged: (v) {
                    setState(() {
                      l.precioUnitario = double.tryParse(v) ?? 0.0;
                    });
                  },
                ),
              ),
              const Spacer(),
              Text(_currency.format(l.subtotal),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.colSalidas)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepper({
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _stepperBtn(Icons.remove, value > min
            ? () => onChanged(value - 1)
            : null),
        Container(
          width: 36, alignment: Alignment.center,
          child: Text('$value',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        _stepperBtn(Icons.add, value < max
            ? () => onChanged(value + 1)
            : null),
      ],
    );
  }

  Widget _stepperBtn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: onTap == null
              ? const Color(0xFFF0F0F0)
              : AppColors.colSalidas.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            size: 18,
            color: onTap == null ? AppColors.textHint : AppColors.colSalidas),
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
  final String categoria;
  final int    stockActual;
  final double precioUnitario;

  const _ProductoLite({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.stockActual,
    required this.precioUnitario,
  });

  factory _ProductoLite.fromJson(Map<String, dynamic> j) => _ProductoLite(
    id:             j['id_producto']    as int,
    codigo:         j['codigo']         as String,
    nombre:         j['nombre']         as String,
    categoria:      '',
    stockActual:    j['stock_actual']   as int,
    precioUnitario: (j['precio_unitario'] as num? ?? 0).toDouble(),
  );
}
