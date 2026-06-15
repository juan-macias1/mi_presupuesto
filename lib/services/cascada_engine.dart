import '../models/cascada_mensual.dart';
import '../models/modo_financiero.dart';

/// CascadaEngine — arma el plan del mes como cascada priorizada.
///
/// Reparte el ingreso EN ORDEN (no sobre lo que sobró):
///   ingreso − gastos fijos − cuotas − 10% (me pago primero) − subsistencia
///   = margen para atacar deuda (o metas si no hay deuda).
/// Las variables salen del margen, por eso son la palanca del mes.
///
/// Nota honesta: como la app todavía no trackea el saldo del fondo/colchón,
/// el destino del 10% se muestra como recomendación (a dónde DEBERÍA ir),
/// no como un llenado con progreso real. Eso es trabajo futuro.
class CascadaEngine {
  CascadaMensual calcular({
    required double ingresos,
    required double gastosFijos,
    required double cuotasDeuda,
    required double subsistencia,
    required ModoFinanciero modo,
    required bool hayDatosSuficientes,
  }) {
    // Sin datos creíbles no inventamos una cascada sobre cifras infladas.
    if (!hayDatosSuficientes || ingresos <= 0) {
      return CascadaMensual.datosInsuficientes();
    }

    // El 10% es sagrado: sale siempre, sobre el ingreso bruto.
    final pagatePrimero = ingresos * 0.10;

    // El destino del 10% y del margen cambia según el modo.
    final String destinoPagate;
    final String destinoMargen;
    if (modo == ModoFinanciero.libertad) {
      destinoPagate = 'Fondo completo, luego inversión';
      destinoMargen = 'Metas e inversión';
    } else {
      destinoPagate = 'Colchón de 1 mes, luego a la deuda';
      destinoMargen = 'Atacar la deuda';
    }

    final margen =
        ingresos - gastosFijos - cuotasDeuda - pagatePrimero - subsistencia;

    final String mensaje;
    if (margen <= 0) {
      mensaje =
          'Después de lo innegociable, tu 10% y la subsistencia, no te queda '
          'margen este mes. Bajar un gasto fijo es lo que más libera.';
    } else if (modo == ModoFinanciero.libertad) {
      mensaje =
          'Tu margen del mes va completo a metas e inversión. Sin deudas, '
          'cada peso construye.';
    } else {
      mensaje =
          'Este es tu margen para atacar la deuda. Lo que te aguantes en '
          'gastos variables, súmalo acá: es tu palanca del mes.';
    }

    return CascadaMensual(
      datosSuficientes: true,
      ingresos: ingresos,
      gastosFijos: gastosFijos,
      cuotasDeuda: cuotasDeuda,
      pagatePrimero: pagatePrimero,
      destinoPagatePrimero: destinoPagate,
      subsistencia: subsistencia,
      destinoMargen: destinoMargen,
      mensaje: mensaje,
    );
  }
}
