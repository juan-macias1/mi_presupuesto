import '../db/database_helper.dart';
import '../models/movimiento.dart';
import '../models/financial_distribution.dart';

class DistributionEngine {
  final db = DatabaseHelper.instance;

  Future<FinancialDistribution> calcularDistribucion() async {
    final movimientosMap = await db.obtenerMovimientos();
    List<Movimiento> movimientos = movimientosMap
        .map((m) => Movimiento.fromMap(m))
        .toList();

    // Guard: sin datos
    if (movimientos.isEmpty) {
      return FinancialDistribution(
        ingresos: 0,
        gastosFijos: 0,
        excedenteReal: 0,
        fase: "SIN_DATOS",
        descripcionFase:
            "Registra tus movimientos para ver tu plan de distribución.",
        porcentajeDeuda: 0,
        porcentajeFondo: 0,
        porcentajeMetas: 0,
        montoDeuda: 0,
        montoFondo: 0,
        montoMetas: 0,
        mesesParaSalirDeDeuda: 0,
        mesesParaFondoCompleto: 0,
        fondoEmergenciaObjetivo: 0,
        mensaje: "Comienza registrando tus ingresos y gastos fijos.",
      );
    }

    // ── Calcular totales ──────────────────────────────────────────────────────
    double ingresos = 0;
    double gastosFijos = 0;
    double gastosVariables = 0;
    double totalDeuda = 0;

    for (var m in movimientos) {
      if (m.tipo == "ingreso") {
        ingresos += m.valor;
      } else if (m.tipo == "gasto") {
        if (m.esDeuda) {
          // Las deudas se cuentan SOLO como deuda, nunca como gasto operativo
          totalDeuda += m.valor;
        } else if (m.esFijo) {
          gastosFijos += m.valor;
        } else {
          gastosVariables += m.valor;
        }
      }
    }

    // Excedente real = lo que queda después de gastos fijos (sin contar deudas aún)
    double excedenteReal = ingresos - gastosFijos - gastosVariables - totalDeuda;

    if (excedenteReal <= 0) {
      return FinancialDistribution(
        ingresos: ingresos,
        gastosFijos: gastosFijos,
        excedenteReal: excedenteReal,
        fase: "CRITICA",
        descripcionFase:
            "Tus gastos e deudas consumen todos tus ingresos. Es urgente reducir gastos variables.",
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
            "No queda excedente después de gastos y deudas. Reducir al menos un gasto variable cambiaría tu situación.",
      );
    }

    // ── Determinar fase ───────────────────────────────────────────────────────
    double ratioDeuda = ingresos == 0 ? 0 : totalDeuda / ingresos;

    String fase;
    String descripcionFase;
    double porcentajeDeuda;
    double porcentajeFondo;
    double porcentajeMetas;

    if (ratioDeuda > 1.0) {
      // FASE CRÍTICA: deuda supera ingresos
      fase = "CRITICA";
      descripcionFase =
          "Tu deuda es mayor que tus ingresos. El enfoque ahora es eliminarla agresivamente.";
      porcentajeDeuda = 0.70;
      porcentajeFondo = 0.20;
      porcentajeMetas = 0.10;
    } else if (ratioDeuda > 0.3) {
      // FASE MODERADA: deuda manejable pero significativa
      fase = "MODERADA";
      descripcionFase =
          "Tienes deuda manejable. Equilibrar deuda, fondo y metas es la clave ahora.";
      porcentajeDeuda = 0.50;
      porcentajeFondo = 0.30;
      porcentajeMetas = 0.20;
    } else {
      // FASE ESTABLE: sin deuda o deuda mínima
      fase = "ESTABLE";
      descripcionFase =
          "Tus finanzas están estables. Es momento de construir patrimonio.";
      porcentajeDeuda = totalDeuda > 0 ? 0.10 : 0.0;
      porcentajeFondo = 0.40;
      porcentajeMetas = totalDeuda > 0 ? 0.50 : 0.60;
    }

    // ── Calcular montos concretos ─────────────────────────────────────────────
    double montoDeuda = excedenteReal * porcentajeDeuda;
    double montoFondo = excedenteReal * porcentajeFondo;
    double montoMetas = excedenteReal * porcentajeMetas;

    // ── Proyecciones ──────────────────────────────────────────────────────────
    int mesesParaSalirDeDeuda = 0;
    if (montoDeuda > 0 && totalDeuda > 0) {
      mesesParaSalirDeDeuda = (totalDeuda / montoDeuda).ceil();
    }

    // Fondo basado en gastos FIJOS (lo mínimo para sobrevivir)
    double fondoObjetivo = gastosFijos * 6;
    int mesesParaFondo = 0;
    if (montoFondo > 0 && fondoObjetivo > 0) {
      mesesParaFondo = (fondoObjetivo / montoFondo).ceil();
    }

    // ── Mensaje personalizado ─────────────────────────────────────────────────
    String mensaje;
    if (fase == "CRITICA") {
      mensaje =
          "Con \$${montoDeuda.toStringAsFixed(0)} mensuales al pago de deuda, "
          "saldrías de ella en $mesesParaSalirDeDeuda meses. "
          "Mientras tanto, destina \$${montoFondo.toStringAsFixed(0)} a tu fondo de emergencia.";
    } else if (fase == "MODERADA") {
      mensaje =
          "Destinando \$${montoDeuda.toStringAsFixed(0)} a deuda y "
          "\$${montoFondo.toStringAsFixed(0)} al fondo de emergencia, "
          "en $mesesParaSalirDeDeuda meses estarías libre de deuda "
          "y en $mesesParaFondo meses tendrías tu fondo completo.";
    } else {
      mensaje =
          "Puedes destinar \$${montoMetas.toStringAsFixed(0)} mensuales a tus metas e inversión. "
          "Tu fondo de emergencia estaría completo en $mesesParaFondo meses.";
    }

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
}
