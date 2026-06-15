/// CascadaMensual — el plan del mes como cascada priorizada.
///
/// A diferencia de la distribución (que reparte lo que SOBRÓ tras gastar),
/// la cascada reparte el ingreso EN ORDEN: primero lo innegociable (gastos
/// fijos + cuotas), luego el 10% sagrado de "me pago primero", luego la
/// reserva de subsistencia, y lo que queda es el MARGEN para atacar deuda
/// (o metas si no hay deuda). Las variables salen del margen — son la
/// palanca del mes.
class CascadaMensual {
  final bool datosSuficientes;
  final double ingresos;
  final double gastosFijos;
  final double cuotasDeuda;

  /// 10% del ingreso. Sagrado: sale siempre.
  final double pagatePrimero;

  /// A dónde va el 10% según el modo (recomendación, no saldo real).
  final String destinoPagatePrimero;

  /// Reserva de subsistencia = gastos reales en Alimentación + Transporte.
  final double subsistencia;

  /// A dónde va el margen según el modo ("Atacar la deuda" / "Metas").
  final String destinoMargen;

  final String mensaje;

  const CascadaMensual({
    required this.datosSuficientes,
    required this.ingresos,
    required this.gastosFijos,
    required this.cuotasDeuda,
    required this.pagatePrimero,
    required this.destinoPagatePrimero,
    required this.subsistencia,
    required this.destinoMargen,
    required this.mensaje,
  });

  // ── Remanentes de la cascada (para dibujar el waterfall en orden) ──
  double get trasFijos => ingresos - gastosFijos;
  double get trasCuotas => trasFijos - cuotasDeuda;
  double get trasPagatePrimero => trasCuotas - pagatePrimero;

  /// Lo que queda tras todos los pasos. Puede ser negativo (supervivencia).
  double get margen => trasPagatePrimero - subsistencia;

  /// Estado honesto: hay ingresos pero faltan gastos creíbles para el plan.
  factory CascadaMensual.datosInsuficientes() {
    return const CascadaMensual(
      datosSuficientes: false,
      ingresos: 0,
      gastosFijos: 0,
      cuotasDeuda: 0,
      pagatePrimero: 0,
      destinoPagatePrimero: '',
      subsistencia: 0,
      destinoMargen: '',
      mensaje:
          'Registra tus gastos del mes para ver tu cascada: cuánto va a lo '
          'fijo, a tu 10%, a subsistencia y cuánto te queda para la deuda.',
    );
  }

  factory CascadaMensual.empty() {
    return const CascadaMensual(
      datosSuficientes: false,
      ingresos: 0,
      gastosFijos: 0,
      cuotasDeuda: 0,
      pagatePrimero: 0,
      destinoPagatePrimero: '',
      subsistencia: 0,
      destinoMargen: '',
      mensaje: '',
    );
  }
}
