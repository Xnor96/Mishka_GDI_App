// Mirrors Go: infrastructure/http/dto/response.go → ProductoResponse
class Producto {
  final int    id;
  final String codigo;
  final String nombre;
  final int?   idCategoria;
  final String unidadMedida;
  final double precioUnitario;
  final int    stockActual;
  final int    stockInicial;

  const Producto({
    required this.id,
    required this.codigo,
    required this.nombre,
    this.idCategoria,
    required this.unidadMedida,
    required this.precioUnitario,
    required this.stockActual,
    required this.stockInicial,
  });

  factory Producto.fromJson(Map<String, dynamic> json) => Producto(
    id:             json['id_producto'] as int,
    codigo:         json['codigo']       as String,
    nombre:         json['nombre']       as String,
    idCategoria:    json['id_categoria'] as int?,
    unidadMedida:   (json['unidad_medida'] ?? '') as String,
    precioUnitario: (json['precio_unitario'] as num).toDouble(),
    stockActual:    json['stock_actual']   as int,
    stockInicial:   json['stock_inicial']  as int,
  );

  // ── Helpers de negocio ────────────────────────────────────────────
  bool get sinStock    => stockActual == 0;
  bool get stockBajo   => stockActual > 0 && stockActual <= 3;
  bool get stockNormal => stockActual > 3;

  /// Nombre de categoría a partir del id (sin hit de red)
  static const Map<int, String> _cats = {
    1: 'ANILLO', 2: 'ARETE', 3: 'COLLAR',
    4: 'JUEGO',  5: 'OTRO',  6: 'PULSERA',
  };
  String get categoriaNombre =>
      idCategoria != null ? (_cats[idCategoria!] ?? '—') : '—';
}
