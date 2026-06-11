import '../db/database_helper.dart';
import '../models/deuda.dart';
import '../models/plan_pago.dart';

class DeudaEngine {
  final db = DatabaseHelper.instance;

  // ── Análisis completo de deudas ───────────────────────────
  Future<PlanPago> generarPlanPago(double disponibleMensual) async {
    final deudasData = await db.obtenerDeudas();

    // Guard: sin deudas
    if (deudasData.isEmpty) {
      return PlanPago.sinDeudas();
    }

    final List<Deuda> deudas =
        deudasData.map((d) => Deuda.fromMap(d)).toList();

    final double totalDeuda =
        deudas.fold(0.0, (s, d) => s + d.saldoActual);
    final double cuotasTotales =
        deudas.fold(0.0, (s, d) => s + d.cuotaMensual);

    // Guard: disponible insuficiente para cubrir mínimos
    if (disponibleMensual < cuotasTotales) {
      return PlanPago(
        deudas: deudas,
        totalDeuda: totalDeuda,
        disponibleMensual: disponibleMensual,
        mesesParaLiberarse: -1,
        fechaLiberacion: null,
        estrategia: 'INSUFICIENTE',
        mensajeEstrategia:
            'Tu disponible (\$${disponibleMensual.toStringAsFixed(0)}) '
            'no cubre las cuotas mínimas (\$${cuotasTotales.toStringAsFixed(0)}). '
            'Necesitas reducir gastos urgente.',
        detallePorDeuda: [],
        excedenteMensual: disponibleMensual - cuotasTotales,
        ahorroEnIntereses: 0,
      );
    }

    // ── Método híbrido ────────────────────────────────────────
    // Con interés → avalancha (mayor interés primero)
    // Sin interés → bola de nieve (menor saldo primero)
    final List<Deuda> deudasConInteres =
        deudas.where((d) => d.tasaInteres > 0).toList();
    final List<Deuda> deudasSinInteres =
        deudas.where((d) => d.tasaInteres == 0).toList();

    deudasConInteres.sort(
      (a, b) => b.tasaInteres.compareTo(a.tasaInteres),
    );
    deudasSinInteres.sort(
      (a, b) => a.saldoActual.compareTo(b.saldoActual),
    );

    final List<Deuda> deudasOrdenadas = [
      ...deudasConInteres,
      ...deudasSinInteres,
    ];

    // ── Simular pagos ─────────────────────────────────────────
    final List<DetallePago> detalle =
        _simularPagos(deudasOrdenadas, disponibleMensual);

    final int mesesTotal = detalle.isEmpty
        ? 0
        : detalle
            .map((d) => d.mesesParaPagar)
            .reduce((a, b) => a > b ? a : b);

    final DateTime? fechaLiberacion = mesesTotal > 0
        ? DateTime.now().add(Duration(days: mesesTotal * 30))
        : null;

    final int mesesSoloMinimos = _calcularMesesSoloMinimos(deudas);
    final double ahorroMeses =
        (mesesSoloMinimos - mesesTotal).toDouble().clamp(0.0, double.infinity).toDouble();

    String estrategia;
    String mensajeEstrategia;

    if (mesesTotal <= 6) {
      estrategia = 'SPRINT';
      mensajeEstrategia =
          '🚀 ¡Estás a $mesesTotal meses de quedar libre de deudas! '
          'Con disciplina esto es muy alcanzable.';
    } else if (mesesTotal <= 12) {
      estrategia = 'AGRESIVA';
      mensajeEstrategia =
          '💪 En $mesesTotal meses puedes quedar libre. '
          'Un año de sacrificio para una vida sin deudas.';
    } else if (mesesTotal <= 24) {
      estrategia = 'PROGRESIVA';
      mensajeEstrategia =
          '📈 $mesesTotal meses para liberarte. Cada peso extra '
          'que destines acorta este tiempo significativamente.';
    } else {
      estrategia = 'LARGO_PLAZO';
      mensajeEstrategia =
          '🎯 $mesesTotal meses al ritmo actual. Considera aumentar '
          'tus ingresos o reducir gastos para acelerar el proceso.';
    }

    return PlanPago(
      deudas: deudasOrdenadas,
      totalDeuda: totalDeuda,
      disponibleMensual: disponibleMensual,
      mesesParaLiberarse: mesesTotal,
      fechaLiberacion: fechaLiberacion,
      estrategia: estrategia,
      mensajeEstrategia: mensajeEstrategia,
      detallePorDeuda: detalle,
      excedenteMensual: disponibleMensual - cuotasTotales,
      ahorroEnIntereses: ahorroMeses,
    );
  }

  // ── Simulación mes a mes bola de nieve ────────────────────
  List<DetallePago> _simularPagos(
    List<Deuda> deudasOrdenadas,
    double disponibleMensual,
  ) {
    // Copia mutable de saldos
    final Map<int, double> saldos = {
      for (final Deuda d in deudasOrdenadas)
        if (d.id != null) d.id!: d.saldoActual,
    };

    final Map<int, int> mesesPorDeuda = {};
    final Map<int, double> pagadoExtra = {};

    int mes = 0;
    const int maxMeses = 360;

    while (saldos.values.any((s) => s > 0) && mes < maxMeses) {
      mes++;
      double disponibleRestante = disponibleMensual;

      // Paso 1: pagar mínimos
      for (final Deuda deuda in deudasOrdenadas) {
        if (deuda.id == null) continue;
        final int id = deuda.id!;
        if ((saldos[id] ?? 0) <= 0) continue;

        final double pago = (saldos[id]! < deuda.cuotaMensual)
            ? saldos[id]!
            : deuda.cuotaMensual;
        saldos[id] = saldos[id]! - pago;
        disponibleRestante -= pago;

        if (saldos[id]! <= 0) mesesPorDeuda[id] = mes;
      }

      // Paso 2: bola de nieve — excedente a la primera deuda activa
      if (disponibleRestante > 0) {
        for (final Deuda deuda in deudasOrdenadas) {
          if (deuda.id == null) continue;
          final int id = deuda.id!;
          if ((saldos[id] ?? 0) <= 0) continue;

          final double pagoExtra = (saldos[id]! < disponibleRestante)
              ? saldos[id]!
              : disponibleRestante;
          saldos[id] = saldos[id]! - pagoExtra;
          pagadoExtra[id] = (pagadoExtra[id] ?? 0) + pagoExtra;
          disponibleRestante -= pagoExtra;

          if (saldos[id]! <= 0) mesesPorDeuda[id] = mes;
          if (disponibleRestante <= 0) break;
        }
      }
    }

    return deudasOrdenadas
        .where((d) => d.id != null)
        .map((Deuda deuda) {
          final int id = deuda.id!;
          final int meses = mesesPorDeuda[id] ?? maxMeses;
          final double extra = pagadoExtra[id] ?? 0;
          final DateTime fechaPago =
              DateTime.now().add(Duration(days: meses * 30));

          return DetallePago(
            deudaId: id,
            acreedor: deuda.acreedor,
            saldoActual: deuda.saldoActual,
            cuotaMensual: deuda.cuotaMensual,
            pagoExtraPromedio: meses > 0 ? extra / meses : 0,
            mesesParaPagar: meses,
            fechaEstimadaPago: fechaPago,
            esPrioridad: deudasOrdenadas.indexOf(deuda) == 0,
          );
        })
        .toList();
  }

  // ── Meses pagando solo mínimos ────────────────────────────
  int _calcularMesesSoloMinimos(List<Deuda> deudas) {
    int maxMeses = 0;
    for (final Deuda deuda in deudas) {
      if (deuda.cuotaMensual <= 0) continue;
      final int meses = (deuda.saldoActual / deuda.cuotaMensual).ceil();
      if (meses > maxMeses) maxMeses = meses;
    }
    return maxMeses;
  }

  // ── Simular pago extra ────────────────────────────────────
  Future<Map<String, dynamic>> simularPagoExtra(double pagoExtra) async {
    final List<Map<String, dynamic>> deudasData = await db.obtenerDeudas();
    if (deudasData.isEmpty) {
      return {'mesesAhorrados': 0, 'mensaje': 'No tienes deudas activas.'};
    }

    final List<Deuda> deudas =
        deudasData.map((d) => Deuda.fromMap(d)).toList();
    final double cuotasBase =
        deudas.fold(0.0, (s, d) => s + d.cuotaMensual);

    final PlanPago planActual = await generarPlanPago(cuotasBase);
    final PlanPago planConExtra = await generarPlanPago(cuotasBase + pagoExtra);

    final int mesesAhorrados =
        planActual.mesesParaLiberarse - planConExtra.mesesParaLiberarse;

    return {
      'mesesAhorrados': mesesAhorrados,
      'mesesActual': planActual.mesesParaLiberarse,
      'mesesConExtra': planConExtra.mesesParaLiberarse,
      'mensaje': mesesAhorrados > 0
          ? 'Pagando \$${pagoExtra.toStringAsFixed(0)} extra al mes '
            'te liberas $mesesAhorrados meses antes.'
          : 'Con ese extra no hay diferencia significativa aún.',
    };
  }

  // ── Registrar pago y actualizar saldo ─────────────────────
  Future<void> registrarPago(int deudaId, double montoPagado) async {
    final List<Map<String, dynamic>> deudasData =
        await db.obtenerTodasLasDeudas();

    final Map<String, dynamic>? deudaMap = deudasData
        .where((d) => d['id'] == deudaId)
        .cast<Map<String, dynamic>?>()
        .firstWhere((_) => true, orElse: () => null);

    if (deudaMap == null) return;

    final Deuda deuda = Deuda.fromMap(deudaMap);
    final double nuevoSaldo =
        (deuda.saldoActual - montoPagado).clamp(0.0, double.infinity).toDouble();
    await db.actualizarSaldoDeuda(deudaId, nuevoSaldo);
  }

  // ── Resumen rápido para el dashboard ─────────────────────
  Future<Map<String, dynamic>> resumenDeudas() async {
    final double totalDeuda = await db.obtenerTotalDeudaReal();
    final List<Map<String, dynamic>> deudasData = await db.obtenerDeudas();

    if (deudasData.isEmpty) {
      return {
        'totalDeuda': 0.0,
        'cantidadDeudas': 0,
        'modoApp': 'LIBERTAD',
        'mensaje': '🎉 ¡Sin deudas! Estás en modo libertad financiera.',
      };
    }

    final List<Deuda> deudas =
        deudasData.map((d) => Deuda.fromMap(d)).toList();
    final double cuotasTotales =
        deudas.fold(0.0, (s, d) => s + d.cuotaMensual);
    final Deuda deudaPrioritaria = deudas.first;

    return {
      'totalDeuda': totalDeuda,
      'cantidadDeudas': deudas.length,
      'cuotasTotales': cuotasTotales,
      'deudaMasUrgente': deudaPrioritaria.acreedor,
      'saldoMasUrgente': deudaPrioritaria.saldoActual,
      'modoApp': 'DEUDA',
      'mensaje':
          'Tienes ${deudas.length} '
          'deuda${deudas.length > 1 ? "s" : ""} '
          'por \$${totalDeuda.toStringAsFixed(0)} en total.',
    };
  }
}
