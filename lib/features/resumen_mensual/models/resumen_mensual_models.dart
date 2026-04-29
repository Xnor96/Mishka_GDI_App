import 'package:flutter/foundation.dart';

@immutable
class ResumenMensual {
  final int    id;
  final int    mes;
  final String nombreMes;
  final int    anio;
  final double totalIngresos;
  final double totalGastosFijos;
  final double totalGastosVariables;
  final double balance;
  final String observaciones;
  final DateTime fechaGeneracion;

  const ResumenMensual({
    required this.id,
    required this.mes,
    required this.nombreMes,
    required this.anio,
    required this.totalIngresos,
    required this.totalGastosFijos,
    required this.totalGastosVariables,
    required this.balance,
    required this.observaciones,
    required this.fechaGeneracion,
  });

  factory ResumenMensual.fromJson(Map<String, dynamic> j) => ResumenMensual(
    id:                  j['id_resumen']             as int,
    mes:                 j['mes']                    as int,
    nombreMes:           j['nombre_mes']             as String,
    anio:                j['anio']                   as int,
    totalIngresos:       (j['total_ingresos']        as num).toDouble(),
    totalGastosFijos:    (j['total_gastos_fijos']    as num).toDouble(),
    totalGastosVariables:(j['total_gastos_variables'] as num).toDouble(),
    balance:             (j['balance']               as num).toDouble(),
    observaciones:       j['observaciones']          as String,
    fechaGeneracion:     DateTime.parse(j['fecha_generacion'] as String),
  );
}
