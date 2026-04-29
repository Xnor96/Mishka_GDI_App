/// Mirrors Go: EntradaProductoResponse
class Entrada {
  final int     id;
  final int     idProducto;
  final String  codigoProducto;
  final String  nombreProducto;
  final String  nombreCategoria;
  final DateTime fechaEntrada;
  final int     cantidad;
  final double? precioUnitario;   // nullable — el Excel no siempre tiene precio de compra
  final String  observaciones;
  final String  usuarioRegistro;

  const Entrada({
    required this.id,
    required this.idProducto,
    required this.codigoProducto,
    required this.nombreProducto,
    required this.nombreCategoria,
    required this.fechaEntrada,
    required this.cantidad,
    this.precioUnitario,
    required this.observaciones,
    required this.usuarioRegistro,
  });

  factory Entrada.fromJson(Map<String, dynamic> j) => Entrada(
    id:               j['id_entrada']        as int,
    idProducto:       j['id_producto']       as int,
    codigoProducto:   j['codigo_producto']   as String,
    nombreProducto:   j['nombre_producto']   as String,
    nombreCategoria:  j['nombre_categoria']  as String,
    fechaEntrada:     DateTime.parse(j['fecha_entrada'] as String),
    cantidad:         j['cantidad']          as int,
    precioUnitario:   j['precio_unitario'] != null
        ? (j['precio_unitario'] as num).toDouble()
        : null,
    observaciones:    (j['observaciones'] ?? '') as String,
    usuarioRegistro:  (j['usuario_registro'] ?? '') as String,
  );
}
