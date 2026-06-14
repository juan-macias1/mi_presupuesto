import '../models/financial_distribution.dart';
import '../models/flujo_mensual.dart';

/// DistributionEngine — calcula cómo distribuir el excedente del mes.
///
/// IMPORTANTE: ya NO lee la base de datos por su cuenta. Consume el
/// FlujoMensual que el MasterFinancialBrain ya calculó (única fuente de
/// verdad, mes correcto). Antes recalculaba con el histórico completo, lo
/// que producía un excedente inflado e inconsistente con el resto de la app.
class DistributionEngine {
  /// Calcula la distribución a partir del flujo del mes.
  ///
  /// [hayDatosSuficientes]: si es false (confianza insuficiente o sin
  /// gastos creíbles), NO inventamos un plan sobre un excedente irreal —
  /// devolvemos el estado 'datos insuficientes' que pide cargar gastos.
  FinancialDistribution calcular(
    FlujoMensual flujo, {
    required bool hayDatosSuficientes,
  }) {
    // Guard 1: sin ingresos, no hay nada que distribuir.
    if (flujo.ingresos <= 0) {
      return FinancialDistribution.empty();
    }

    // Guard 2: datos insuficientes — el corazón del arreglo de raíz.
    // Si no podemos confiar en los gastos, no calculamos distribución:
    // sería repartir un excedente que no existe de verdad.
    if (!hayDatosSuficientes) {
      return FinancialDistribution.datosInsuficientes(
        ingresos: flujo.ingresos,
      );
    }

    final ingresos = flujo.ingresos;
    final gastosFijos = flujo.gastosFijos;
    final totalDeuda = flujo.totalDeudaReal;

    // Excedente real desde el flujo: lo que queda tras gastos operativos
    // y cuotas de deuda. Usamos disponibleNeto, que ya está bien calculado.
    final excedenteReal = flujo.disponibleNeto;

    // Guard 3: sin excedente, fase crítica.
    if (excedenteReal <= 0) {
      return FinancialDistribution(
        ingresos: ingresos,
        gastosFijos: gastosFijos,
        excedenteReal: excedenteReal,
        fase: 'CRITICA',
        descripcionFase:
            'Tus gastos y deudas consumen todos tus ingresos. '
            'Es urgente reducir un gasto.',
        porcentajeDeuda: 0,
        porcentajeFondo: 0,
        porcentajeMetas: 0,
        montoDeuda: 0,
        montoFondo: 0,
        montoMetas: 0,
        mesesParaSalirDeDeuda: 0,
        mesesParaFondoCompleto: 0,
        fondoEmergenciaObjetivo: gastosFijos * 6,
        mensaje:
            'No queda excedente después de gastos y deudas. Reducir al menos '
            'un gasto variable cambiaría tu situación.',
      );
    }

    // ── Determinar fase según ratio de deuda ──
    final ratioDeuda = ingresos == 0 ? 0.0 : totalDeuda / ingresos;

    String fase;
    String descripcionFase;
    double porcentajeDeuda;
    double porcentajeFondo;
    double porcentajeMetas;

    if (ratioDeuda > 1.0) {
      fase = 'CRITICA';
      descripcionFase =
          'Tu deuda es mayor que tus ingresos. El enfoque ahora es '
          'eliminarla agresivamente.';
      porcentajeDeuda = 0.70;
      porcentajeFondo = 0.20;
      porcentajeMetas = 0.10;
    } else if (ratioDeuda > 0.3) {
      fase = 'MODERADA';
      descripcionFase =
          'Tienes deuda manejable. Equilibrar deuda, fondo y metas es la '
          'clave ahora.';
      porcentajeDeuda = 0.50;
      porcentajeFondo = 0.30;
      porcentajeMetas = 0.20;
    } else {
      fase = 'ESTABLE';
      descripcionFase =
          'Tus finanzas están estables. Es momento de construir patrimonio.';
      porcentajeDeuda = totalDeuda > 0 ? 0.10 : 0.0;
      porcentajeFondo = 0.40;
      porcentajeMetas = totalDeuda > 0 ? 0.50 : 0.60;
    }

    final montoDeuda = excedenteReal * porcentajeDeuda;
    final montoFondo = excedenteReal * porcentajeFondo;
    final montoMetas = excedenteReal * porcentajeMetas;

    // ── Proyecciones ──
    int mesesParaSalirDeDeuda = 0;
    if (montoDeuda > 0 && totalDeuda > 0) {
      mesesParaSalirDeDeuda = (totalDeuda / montoDeuda).ceil();
    }

    final fondoObjetivo = gastosFijos * 6;
    int mesesParaFondo = 0;
    if (montoFondo > 0 && fondoObjetivo > 0) {
      mesesParaFondo = (fondoObjetivo / montoFondo).ceil();
    }

    // ── Mensaje (con plurales correctos) ──
    final mensaje = _construirMensaje(
      fase: fase,
      montoDeuda: montoDeuda,
      montoFondo: montoFondo,
      montoMetas: montoMetas,
      mesesParaSalirDeDeuda: mesesParaSalirDeDeuda,
      mesesParaFondo: mesesParaFondo,
    );

    return FinancialDistribution(
      ingresos: ingresos,
      gastosFijos: gastosFijos,
      excedenteReal: excedenteReal,
      fase: fase,
      descripcionFase: descripcionFase,
      porcentajeDeuda: porcentajeDeuda,
      porcentajeFondo: porcentajeFondo,
      porcentajeMetas: porcentajeMetas,
      montoDeuda: montoDeuda,
      montoFondo: montoFondo,
      montoMetas: montoMetas,
      mesesParaSalirDeDeuda: mesesParaSalirDeDeuda,
      mesesParaFondoCompleto: mesesParaFondo,
      fondoEmergenciaObjetivo: fondoObjetivo,
      mensaje: mensaje,
    );
  }

  /// Helper de plurales: "1 mes" vs "2 meses", y evita el "0 meses" feo.
  String _meses(int n) => n == 1 ? '1 mes' : '$n meses';

  String _construirMensaje({
    required String fase,
    required double montoDeuda,
    required double montoFondo,
    required double montoMetas,
    required int mesesParaSalirDeDeuda,
    required int mesesParaFondo,
  }) {
    String fmt(double v) => v.toStringAsFixed(0);

    if (fase == 'CRITICA') {
      final libre = mesesParaSalirDeDeuda > 0
          ? ' Saldrías de ella en ${_meses(mesesParaSalirDeDeuda)}.'
          : '';
      return 'Destina \$${fmt(montoDeuda)} mensuales al pago de deuda.$libre '
          'Mientras tanto, aparta \$${fmt(montoFondo)} para tu fondo de '
          'emergencia.';
    } else if (fase == 'MODERADA') {
      final libre = mesesParaSalirDeDeuda > 0
          ? 'en ${_meses(mesesParaSalirDeDeuda)} estarías libre de deuda'
          : 'avanzarías con tu deuda';
      final fondo = mesesParaFondo > 0
          ? ' y en ${_meses(mesesParaFondo)} tendrías tu fondo completo'
          : '';
      return 'Destinando \$${fmt(montoDeuda)} a deuda y \$${fmt(montoFondo)} '
          'al fondo, $libre$fondo.';
    } else {
      final fondo = mesesParaFondo > 0
          ? ' Tu fondo de emergencia estaría completo en '
              '${_meses(mesesParaFondo)}.'
          : '';
      return 'Puedes destinar \$${fmt(montoMetas)} mensuales a tus metas e '
          'inversión.$fondo';
    }
  }
}
