// Refleja AlertasResponse del backend
class AlertaStockBajo {
  final int    idProducto;
  final String codigo;
  final String nombre;
  final String categoria;
  final int    stockActual;
  final int    stockInicial;
  final double precioUnitario;

  AlertaStockBajo({
    required this.idProducto,
    required this.codigo,
    required this.nombre,
    required this.categoria,
    required this.stockActual,
    required this.stockInicial,
    required this.precioUnitario,
  });

  factory AlertaStockBajo.fromJson(Map<String, dynamic> j) => AlertaStockBajo(
    idProducto:     j['id_producto']     ?? 0,
    codigo:         j['codigo']          ?? '',
    nombre:         j['nombre']          ?? '',
    categoria:      j['categoria']       ?? '',
    stockActual:    j['stock_actual']    ?? 0,
    stockInicial:   j['stock_inicial']   ?? 0,
    precioUnitario: (j['precio_unitario'] ?? 0).toDouble(),
  );
}

// Refleja ResumenMensualResponse del backend
class ResumenMensual {
  final int    idResumen;
  final int    mes;
  final String nombreMes;
  final int    anio;
  final double totalIngresos;
  final double totalGastosFijos;
  final double totalGastosVariables;
  final double balance;
  final String observaciones;

  ResumenMensual({
    required this.idResumen,
    required this.mes,
    required this.nombreMes,
    required this.anio,
    required this.totalIngresos,
    required this.totalGastosFijos,
    required this.totalGastosVariables,
    required this.balance,
    required this.observaciones,
  });

  factory ResumenMensual.fromJson(Map<String, dynamic> j) => ResumenMensual(
    idResumen:            j['id_resumen']              ?? 0,
    mes:                  j['mes']                     ?? 0,
    nombreMes:            j['nombre_mes']              ?? '',
    anio:                 j['anio']                    ?? 0,
    totalIngresos:        (j['total_ingresos']         ?? 0).toDouble(),
    totalGastosFijos:     (j['total_gastos_fijos']     ?? 0).toDouble(),
    totalGastosVariables: (j['total_gastos_variables'] ?? 0).toDouble(),
    balance:              (j['balance']                ?? 0).toDouble(),
    observaciones:        j['observaciones']           ?? '',
  );
}

// Refleja ControlDiarioResponse del backend
class ControlDiario {
  final int    idControl;
  final String descripcion;
  final double montoEntrada;
  final double montoSalida;
  final bool   esVerbena;

  ControlDiario({
    required this.idControl,
    required this.descripcion,
    required this.montoEntrada,
    required this.montoSalida,
    required this.esVerbena,
  });

  factory ControlDiario.fromJson(Map<String, dynamic> j) => ControlDiario(
    idControl:    j['id_control']    ?? 0,
    descripcion:  j['descripcion']   ?? '',
    montoEntrada: (j['monto_entrada'] ?? 0).toDouble(),
    montoSalida:  (j['monto_salida']  ?? 0).toDouble(),
    esVerbena:    j['es_verbena']    ?? false,
  );
}

// Refleja ReporteValoracionItem del backend
class ValoracionCategoria {
  final int    idCategoria;
  final String nombreCategoria;
  final int    totalProductos;
  final int    totalUnidades;
  final double valorTotal;

  ValoracionCategoria({
    required this.idCategoria,
    required this.nombreCategoria,
    required this.totalProductos,
    required this.totalUnidades,
    required this.valorTotal,
  });

  factory ValoracionCategoria.fromJson(Map<String, dynamic> j) =>
      ValoracionCategoria(
    idCategoria:     j['id_categoria']      ?? 0,
    nombreCategoria: j['nombre_categoria']  ?? '',
    totalProductos:  j['total_productos']   ?? 0,
    totalUnidades:   j['total_unidades']    ?? 0,
    valorTotal:      (j['valor_total']      ?? 0).toDouble(),
  );
}
