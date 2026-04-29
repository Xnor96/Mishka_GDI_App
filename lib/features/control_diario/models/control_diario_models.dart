import 'package:flutter/foundation.dart';

/// Espejo de ControlDiarioResponse del backend.
@immutable
class ControlDiario {
  final int      id;
  final DateTime fecha;
  final String   descripcion;
  final double   montoEntrada;
  final double   montoSalida;
  final String   observaciones;
  final bool     esVerbena;
  final String   usuarioRegistro;

  const ControlDiario({
    required this.id,
    required this.fecha,
    required this.descripcion,
    required this.montoEntrada,
    required this.montoSalida,
    required this.observaciones,
    required this.esVerbena,
    required this.usuarioRegistro,
  });

  factory ControlDiario.fromJson(Map<String, dynamic> j) => ControlDiario(
    id:              j['id_control']        as int,
    fecha:           DateTime.parse(j['fecha'] as String),
    descripcion:     j['descripcion']       as String,
    montoEntrada:    (j['monto_entrada']    as num).toDouble(),
    montoSalida:     (j['monto_salida']     as num).toDouble(),
    observaciones:   j['observaciones']     as String,
    esVerbena:       j['es_verbena']        as bool,
    usuarioRegistro: j['usuario_registro']  as String,
  );

  double get balance => montoEntrada - montoSalida;
}

/// Totales que devuelve el backend junto con la lista.
@immutable
class ControlDiarioResumen {
  final List<ControlDiario> registros;
  final double totalEntrada;
  final double totalSalida;
  final double balance;

  const ControlDiarioResumen({
    required this.registros,
    required this.totalEntrada,
    required this.totalSalida,
    required this.balance,
  });
}
