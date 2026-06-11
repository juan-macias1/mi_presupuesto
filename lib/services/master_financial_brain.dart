import '../db/database_helper.dart';
import '../models/movimiento.dart';
import '../models/deuda.dart';
import '../models/flujo_mensual.dart';
import '../models/modo_financiero.dart';
import '../models/master_financial_result.dart';
import '../models/financial_analysis.dart';
import '../models/financial_distribution.dart';
import '../models/financial_projection.dart';
import '../models/financial_recommendation.dart';
import '../models/financial_insight.dart';
import '../models/financial_risk.dart';
import '../models/financial_strategy.dart';
import '../models/financial_behavior.dart';
import '../models/money_leak.dart';
import '../models/plan_pago.dart';
import 'deuda_engine.dart';
import 'distribution_engine.dart';

class MasterFinancialBrain {
  static final MasterFinancialBrain instance =
      MasterFinancialBrain._internal();
  MasterFinancialBrain._internal();

  final _db = DatabaseHelper.instance;
  final _deudaEngine = DeudaEngine();
  final _distributionEngine = DistributionEngine();

  // ── Cache para evitar recálculos innecesarios ─────────────
  MasterFinancialResult? _cache;
  DateTime? _ultimoCalculo;
  // Versión de datos cacheada. Se compara contra DatabaseHelper.dataVersion
  // para detectar cambios automáticamente — sin necesidad de que cada pantalla
  // llame a invalidarCache() después de escribir a la DB.
  int? _cacheDataVersion;
  static const _ttlCache = Duration(minutes: 5);

  bool get _cacheValido =>
      _cache != null &&
      _ultimoCalculo != null &&
      _cacheDataVersion == DatabaseHelper.dataVersion &&
      DateTime.now().difference(_ultimoCalculo!) < _ttlCache;

  void invalidarCache() {
    _cache = null;
    _ultimoCalculo = null;
    _cacheDataVersion = null;
  }

  // ── Método principal ──────────────────────────────────────
  Future<MasterFinancialResult> analizar({bool forzar = false}) async {
    if (!forzar && _cacheValido) return _cache!;

    // PASO 1: Leer datos en paralelo
    final datos = await Future.wait([
      _db.obtenerMovimientosMesActual(),
      _db.obtenerMovimientos(),
      _db.obtenerDeudas(),
    ]);

    final movimientosMes =
        datos[0].map((m) => Movimiento.fromMap(m)).toList();

    final movimientosHistorico =
        datos[1].map((m) => Movimiento.fromMap(m)).toList();

    final deudas =
        datos[2].map((d) => Deuda.fromMap(d)).toList();

    // PASO 2: FlujoMensual — números del mes calculados UNA SOLA VEZ
    final flujo = _calcularFlujoMensual(movimientosMes, deudas);

    // PASO 3: ModoFinanciero — determinado automáticamente
    final modo = ModoFinanciero.desde(flujo);

    // Guard: sin datos
    if (modo == ModoFinanciero.sinDatos) {
      final result = MasterFinancialResult.empty();
      _cache = result;
      _ultimoCalculo = DateTime.now();
      _cacheDataVersion = DatabaseHelper.dataVersion;
      return result;
    }

    // PASO 4: PlanPago — solo si hay deudas
    final planPago = deudas.isNotEmpty
        ? await _deudaEngine.generarPlanPago(
            flujo.cuotasDeuda + flujo.disponibleParaDeuda,
          )
        : PlanPago.sinDeudas();

    // PASO 5: FinancialDistribution — basada en flujo real
    final distribucion = await _distributionEngine.calcularDistribucion();

    // PASO 6: FinancialAnalysis — construido desde flujo (no recalcula)
    final analysis = _construirAnalysis(flujo, planPago);

    // PASO 7: Proyección histórica
    final proyeccion = _calcularProyeccion(movimientosHistorico);

    // PASO 8: Insights, riesgos, recomendaciones, comportamiento
    // Todos consumen flujo — sin llamadas redundantes a la DB
    final insights = _generarInsights(flujo, modo);
    final riesgos = _generarRiesgos(flujo, modo);
    final recomendaciones = _generarRecomendaciones(flujo, modo, planPago);
    final estrategias = _generarEstrategias(flujo, modo, proyeccion);
    final comportamiento = _analizarComportamiento(movimientosHistorico);
    final fugas = _detectarFugas(movimientosMes, flujo.ingresos);

    // PASO 9: Score financiero
    final score = _calcularScore(flujo);

    // PASO 10: Contexto IA — string completo listo para Claude
    final contextoIA = _construirContextoIA(
      flujo: flujo,
      modo: modo,
      planPago: planPago,
      distribucion: distribucion,
      proyeccion: proyeccion,
      score: score,
    );

    final result = MasterFinancialResult(
      flujoMensual: flujo,
      modo: modo,
      analysis: analysis,
      distribucion: distribucion,
      proyeccion: proyeccion,
      planPago: planPago,
      insights: insights,
      recomendaciones: recomendaciones,
      riesgos: riesgos,
      estrategias: estrategias,
      comportamiento: comportamiento,
      fugas: fugas,
      scoreFinanciero: score,
      contextoIA: contextoIA,
    );

    _cache = result;
    _ultimoCalculo = DateTime.now();
    _cacheDataVersion = DatabaseHelper.dataVersion;
    return result;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 2: FlujoMensual
  // ══════════════════════════════════════════════════════════
  FlujoMensual _calcularFlujoMensual(
    List<Movimiento> movimientosMes,
    List<Deuda> deudas,
  ) {
    double ingresos = 0;
    double gastosFijos = 0;
    double gastosVariables = 0;

    for (final m in movimientosMes) {
      if (m.tipo == 'ingreso') {
        ingresos += m.valor;
      } else if (m.tipo == 'gasto' && !m.esDeuda) {
        if (m.esFijo) {
          gastosFijos += m.valor;
        } else {
          gastosVariables += m.valor;
        }
      }
    }

    final cuotasDeuda = deudas.fold(0.0, (s, d) => s + d.cuotaMensual);
    final totalDeudaReal = deudas.fold(0.0, (s, d) => s + d.saldoActual);

    return FlujoMensual(
      ingresos: ingresos,
      gastosFijos: gastosFijos,
      gastosVariables: gastosVariables,
      cuotasDeuda: cuotasDeuda,
      totalDeudaReal: totalDeudaReal,
    );
  }

  // ══════════════════════════════════════════════════════════
  // PASO 6: FinancialAnalysis desde flujo
  // ══════════════════════════════════════════════════════════
  FinancialAnalysis _construirAnalysis(
    FlujoMensual flujo,
    PlanPago planPago,
  ) {
    final salud = _evaluarSalud(flujo);

    String prioridad;
    if (flujo.ratioDeuda > 1) {
      prioridad = 'Eliminar deudas urgentes';
    } else if (flujo.ratioDeuda > 0.4) {
      prioridad = 'Reducir deuda de forma progresiva';
    } else if (flujo.totalDeudaReal > 0) {
      prioridad = 'Equilibrar pago de deuda y ahorro';
    } else if (flujo.disponibleNeto <= 0) {
      prioridad = 'Controlar gastos y estabilizar finanzas';
    } else {
      prioridad = 'Construir ahorro y fondo de emergencia';
    }

    String estrategia;
    if (flujo.ratioDeuda > 1) {
      estrategia = 'Fase de recuperación: enfocar pagos de deuda';
    } else if (flujo.ratioDeuda > 0.4) {
      estrategia = 'Reducir deuda progresivamente mientras fortaleces ahorro';
    } else if (flujo.totalDeudaReal > 0) {
      estrategia = 'Deuda manejable: continuar pagos constantes';
    } else {
      estrategia = 'Sin deuda: enfocar en ahorro y crecimiento';
    }

    double ahorroRecomendado = flujo.ingresos * 0.10;
    if (ahorroRecomendado > flujo.disponibleNeto) {
      ahorroRecomendado =
          flujo.disponibleNeto > 0 ? flujo.disponibleNeto * 0.5 : 0;
    }

    return FinancialAnalysis(
      ingresos: flujo.ingresos,
      gastos: flujo.gastosOperativos,
      gastosFijos: flujo.gastosFijos,
      gastosVariables: flujo.gastosVariables,
      dineroDisponible: flujo.disponibleNeto,
      ahorroRecomendado: ahorroRecomendado,
      pagoDeudaRecomendado: flujo.disponibleParaDeuda,
      fondoEmergenciaRecomendado: flujo.fondoEmergenciaIdeal,
      totalDeuda: flujo.totalDeudaReal,
      estrategiaDeuda: estrategia,
      saludFinanciera: salud['estado']!,
      mensajeSalud: salud['mensaje']!,
      mesesParaSalirDeDeuda: planPago.mesesParaLiberarse,
      prioridadFinanciera: prioridad,
      financialScore: _calcularScore(flujo),
    );
  }

  // ══════════════════════════════════════════════════════════
  // PASO 7: Proyección histórica
  // ══════════════════════════════════════════════════════════
  FinancialProjection _calcularProyeccion(List<Movimiento> historico) {
    final Map<String, double> ingresosPorMes = {};
    final Map<String, double> fijosPorMes = {};
    final Map<String, double> variablesPorMes = {};

    for (final m in historico) {
      final clave =
          '${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}';
      if (m.tipo == 'ingreso') {
        ingresosPorMes[clave] = (ingresosPorMes[clave] ?? 0) + m.valor;
      } else if (m.tipo == 'gasto' && !m.esDeuda) {
        if (m.esFijo) {
          fijosPorMes[clave] = (fijosPorMes[clave] ?? 0) + m.valor;
        } else {
          variablesPorMes[clave] = (variablesPorMes[clave] ?? 0) + m.valor;
        }
      }
    }

    if (ingresosPorMes.isEmpty) return FinancialProjection.empty();

    final ingresoPromedio = ingresosPorMes.values.reduce((a, b) => a + b) /
        ingresosPorMes.length;
    final fijoPromedio = fijosPorMes.isEmpty
        ? 0.0
        : fijosPorMes.values.reduce((a, b) => a + b) / fijosPorMes.length;
    final variablePromedio = variablesPorMes.isEmpty
        ? 0.0
        : variablesPorMes.values.reduce((a, b) => a + b) /
              variablesPorMes.length;

    double tendencia = 0;
    if (variablesPorMes.length >= 3) {
      final claves = variablesPorMes.keys.toList()..sort();
      final ultimos = claves.sublist(claves.length - 2);
      final anteriores = claves.sublist(0, claves.length - 2);
      final reciente = ultimos
              .map((k) => variablesPorMes[k]!)
              .reduce((a, b) => a + b) /
          ultimos.length;
      final anterior = anteriores
              .map((k) => variablesPorMes[k]!)
              .reduce((a, b) => a + b) /
          anteriores.length;
      if (anterior > 0) tendencia = (reciente - anterior) / anterior;
    }

    final gastosProyectados =
        fijoPromedio + variablePromedio * (1 + tendencia);
    final ahorroMensual =
        (ingresoPromedio - gastosProyectados).clamp(0.0, double.infinity).toDouble();

    String mensaje;
    if (ahorroMensual <= 0) {
      mensaje =
          'Con la tendencia actual no habría capacidad de ahorro. Reducir gastos es urgente.';
    } else if (tendencia > 0.1) {
      mensaje =
          'Tus gastos están aumentando. Tu ahorro proyectado podría reducirse.';
    } else if (tendencia < -0.1) {
      mensaje = 'Vas muy bien, tus gastos están bajando.';
    } else if (ahorroMensual < 200000) {
      mensaje = 'Tu ahorro proyectado es bajo. Pequeños ajustes ayudan mucho.';
    } else {
      mensaje = 'Buena capacidad de ahorro proyectada. Mantén la disciplina.';
    }

    return FinancialProjection(
      ingresoPromedio: ingresoPromedio,
      gastoPromedio: fijoPromedio + variablePromedio,
      ahorroMensual: ahorroMensual,
      ahorro12Meses: ahorroMensual * 12,
      mensaje: mensaje,
      mesesParaSalirDeDeuda: 0,
      mesesParaFondoCompleto: 0,
    );
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Insights
  // ══════════════════════════════════════════════════════════
  List<FinancialInsight> _generarInsights(
    FlujoMensual flujo,
    ModoFinanciero modo,
  ) {
    final insights = <FinancialInsight>[];

    if (modo == ModoFinanciero.sinDatos) {
      insights.add(FinancialInsight(
        titulo: 'Sin movimientos este mes',
        mensaje: 'Registra tus ingresos y gastos para ver tu análisis.',
        nivel: 'neutro',
      ));
      return insights;
    }

    if (flujo.ingresos == 0) {
      insights.add(FinancialInsight(
        titulo: 'Sin ingresos registrados',
        mensaje: 'Agrega tus ingresos para un análisis completo.',
        nivel: 'alerta',
      ));
      return insights;
    }

    // Ratio gastos operativos
    if (flujo.ratioGastoOperativo > 0.9) {
      insights.add(FinancialInsight(
        titulo: 'Zona de peligro financiero',
        mensaje:
            'Usas el ${(flujo.ratioGastoOperativo * 100).toStringAsFixed(0)}% '
            'de tus ingresos en gastos operativos. Casi sin margen.',
        nivel: 'alerta',
      ));
    } else if (flujo.ratioGastoOperativo < 0.5) {
      insights.add(FinancialInsight(
        titulo: 'Excelente control de gastos',
        mensaje:
            'Solo usas el ${(flujo.ratioGastoOperativo * 100).toStringAsFixed(0)}% '
            'de tus ingresos en gastos. Posición muy sólida.',
        nivel: 'positivo',
      ));
    }

    // Deuda
    if (flujo.ratioDeuda > 1) {
      insights.add(FinancialInsight(
        titulo: 'Deuda crítica',
        mensaje:
            'Tu deuda equivale a ${flujo.ratioDeuda.toStringAsFixed(1)} meses '
            'de ingresos. Prioridad máxima.',
        nivel: 'alerta',
      ));
    } else if (flujo.ratioDeuda > 0.5) {
      insights.add(FinancialInsight(
        titulo: 'Deuda significativa',
        mensaje:
            'Tu deuda equivale al '
            '${(flujo.ratioDeuda * 100).toStringAsFixed(0)}% de tus ingresos.',
        nivel: 'alerta',
      ));
    }

    // Modo libertad
    if (modo == ModoFinanciero.libertad) {
      insights.add(FinancialInsight(
        titulo: '¡Sin deudas!',
        mensaje:
            'Estás en modo libertad financiera. Es momento de hacer crecer tu dinero.',
        nivel: 'positivo',
      ));
    }

    return insights;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Riesgos
  // ══════════════════════════════════════════════════════════
  List<FinancialRisk> _generarRiesgos(
    FlujoMensual flujo,
    ModoFinanciero modo,
  ) {
    final riesgos = <FinancialRisk>[];

    if (modo == ModoFinanciero.sinDatos) {
      riesgos.add(FinancialRisk(
        titulo: 'Sin datos para analizar',
        descripcion: 'Registra movimientos para detectar riesgos.',
        nivel: 'bajo',
      ));
      return riesgos;
    }

    if (modo == ModoFinanciero.supervivencia) {
      riesgos.add(FinancialRisk(
        titulo: 'Ingresos insuficientes',
        descripcion:
            'Tus ingresos no cubren gastos fijos + cuotas de deuda. '
            'Situación crítica.',
        nivel: 'critico',
      ));
    }

    if (flujo.ratioGastoOperativo > 0.95) {
      riesgos.add(FinancialRisk(
        titulo: 'Déficit inminente',
        descripcion:
            'Gastas el ${(flujo.ratioGastoOperativo * 100).toStringAsFixed(0)}% '
            'de tus ingresos en operativos.',
        nivel: 'critico',
      ));
    } else if (flujo.ratioGastoOperativo > 0.8) {
      riesgos.add(FinancialRisk(
        titulo: 'Margen muy reducido',
        descripcion:
            'Gastas el ${(flujo.ratioGastoOperativo * 100).toStringAsFixed(0)}% '
            'de tus ingresos.',
        nivel: 'alto',
      ));
    }

    if (flujo.ratioDeuda > 1.5) {
      riesgos.add(FinancialRisk(
        titulo: 'Deuda crítica',
        descripcion:
            'Tu deuda equivale a ${flujo.ratioDeuda.toStringAsFixed(1)} '
            'meses de ingresos.',
        nivel: 'critico',
      ));
    } else if (flujo.ratioDeuda > 1) {
      riesgos.add(FinancialRisk(
        titulo: 'Deuda alta',
        descripcion:
            'Tu deuda supera tus ingresos mensuales '
            '(${flujo.ratioDeuda.toStringAsFixed(1)}x).',
        nivel: 'alto',
      ));
    }

    if (riesgos.isEmpty) {
      riesgos.add(FinancialRisk(
        titulo: 'Sin riesgos detectados',
        descripcion: 'Tus indicadores están en orden. Sigue así.',
        nivel: 'bajo',
      ));
    }

    return riesgos;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Recomendaciones
  // ══════════════════════════════════════════════════════════
  List<FinancialRecommendation> _generarRecomendaciones(
    FlujoMensual flujo,
    ModoFinanciero modo,
    PlanPago planPago,
  ) {
    final recs = <FinancialRecommendation>[];

    if (modo == ModoFinanciero.sinDatos) {
      recs.add(FinancialRecommendation(
        titulo: 'Empieza a registrar',
        descripcion: 'Aún no hay datos para recomendaciones personalizadas.',
        impacto: 'Con una semana de registros el análisis mejora mucho.',
      ));
      return recs;
    }

    if (modo == ModoFinanciero.supervivencia) {
      recs.add(FinancialRecommendation(
        titulo: 'Reducir un gasto fijo urgente',
        descripcion:
            'Tus gastos fijos + cuotas superan tus ingresos. '
            'Eliminar aunque sea uno cambia todo.',
        impacto:
            'Liberarías \$${flujo.gastosFijos.toStringAsFixed(0)} mensuales mínimo.',
      ));
      return recs;
    }

    if (modo == ModoFinanciero.ataque && planPago.mesesParaLiberarse > 0) {
      recs.add(FinancialRecommendation(
        titulo: 'Acelera el pago de deuda',
        descripcion:
            'Con tu disponible actual te liberas en '
            '${planPago.mesesParaLiberarse} meses. '
            'Cada peso extra que destines reduce ese número.',
        impacto:
            'Tienes \$${flujo.disponibleParaDeuda.toStringAsFixed(0)} disponibles para atacar.',
      ));
    }

    if (flujo.ratioGastoOperativo > 0.7) {
      final ahorro = flujo.gastosVariables * 0.10;
      recs.add(FinancialRecommendation(
        titulo: 'Reduce gastos variables un 10%',
        descripcion:
            'Tus gastos variables son controlables. '
            'Reducirlos un 10% libera flujo real.',
        impacto:
            '\$${ahorro.toStringAsFixed(0)} al mes — '
            '\$${(ahorro * 12).toStringAsFixed(0)} al año.',
      ));
    }

    if (modo == ModoFinanciero.libertad) {
      recs.add(FinancialRecommendation(
        titulo: 'Invierte tu excedente',
        descripcion:
            'Sin deudas, cada peso disponible puede crecer. '
            'Empieza con el fondo de emergencia.',
        impacto:
            'Tu fondo ideal: \$${flujo.fondoEmergenciaIdeal.toStringAsFixed(0)}.',
      ));
    }

    return recs;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Estrategias
  // ══════════════════════════════════════════════════════════
  List<FinancialStrategy> _generarEstrategias(
    FlujoMensual flujo,
    ModoFinanciero modo,
    FinancialProjection proyeccion,
  ) {
    final estrategias = <FinancialStrategy>[];
    if (modo == ModoFinanciero.sinDatos) return estrategias;

    if (modo == ModoFinanciero.ataque) {
      estrategias.add(FinancialStrategy(
        titulo: 'Método bola de nieve',
        descripcion:
            'Paga las deudas más pequeñas primero mientras mantienes mínimos '
            'en las demás. Cada deuda eliminada libera flujo para la siguiente.',
      ));
    }

    if (proyeccion.ahorroMensual > 0) {
      final meses = flujo.fondoEmergenciaIdeal > 0
          ? (flujo.fondoEmergenciaIdeal / proyeccion.ahorroMensual).ceil()
          : 0;
      if (meses > 0) {
        estrategias.add(FinancialStrategy(
          titulo: 'Fondo de emergencia en $meses meses',
          descripcion:
              'Tu fondo ideal es \$${flujo.fondoEmergenciaIdeal.toStringAsFixed(0)} '
              '(6 meses de gastos fijos). Con tu ahorro actual lo logras en $meses meses.',
        ));
      }
    }

    if (modo == ModoFinanciero.libertad &&
        flujo.ratioGastoOperativo < 0.7) {
      final meta20 = flujo.ingresos * 0.20;
      estrategias.add(FinancialStrategy(
        titulo: 'Regla 50/30/20',
        descripcion:
            'Tus finanzas permiten esta estrategia: '
            '50% necesidades, 30% deseos, 20% ahorro. '
            'Meta mensual: \$${meta20.toStringAsFixed(0)}.',
      ));
    }

    return estrategias;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Comportamiento (histórico completo)
  // ══════════════════════════════════════════════════════════
  List<FinancialBehavior> _analizarComportamiento(
    List<Movimiento> historico,
  ) {
    if (historico.isEmpty) return [];

    final comportamientos = <FinancialBehavior>[];
    double finDeSemana = 0;
    double semana = 0;
    final Map<String, double> porCategoria = {};
    final Map<String, double> porMes = {};
    final Map<String, double> ingresosPorMes = {};

    for (final m in historico) {
      final clave = '${m.fecha.year}-${m.fecha.month}';
      if (m.tipo == 'gasto' && !m.esDeuda) {
        if (m.fecha.weekday >= 6) {
          finDeSemana += m.valor;
        } else {
          semana += m.valor;
        }
        porCategoria[m.categoria] =
            (porCategoria[m.categoria] ?? 0) + m.valor;
        porMes[clave] = (porMes[clave] ?? 0) + m.valor;
      }
      if (m.tipo == 'ingreso') {
        ingresosPorMes[clave] = (ingresosPorMes[clave] ?? 0) + m.valor;
      }
    }

    if (finDeSemana > semana * 0.6) {
      comportamientos.add(FinancialBehavior(
        titulo: 'Gastos concentrados en fines de semana',
        mensaje:
            'El fin de semana es cuando más gastas. '
            'Un presupuesto semanal puede ayudarte.',
      ));
    }

    if (porCategoria.length >= 3) {
      final lista = porCategoria.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top3 = lista.take(3).fold(0.0, (s, e) => s + e.value);
      final total = porCategoria.values.fold(0.0, (a, b) => a + b);
      if (total > 0 && top3 / total > 0.75) {
        final top = lista.take(2).map((e) => e.key).join(' y ');
        comportamientos.add(FinancialBehavior(
          titulo: 'Gastos muy concentrados',
          mensaje:
              'Más del ${((top3 / total) * 100).toStringAsFixed(0)}% de tus gastos '
              'están en $top.',
        ));
      }
    }

    if (porMes.length >= 2 && ingresosPorMes.isNotEmpty) {
      final mesMaxIngreso = ingresosPorMes.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
      final gastoEseMes = porMes[mesMaxIngreso] ?? 0;
      final promedio = porMes.values.reduce((a, b) => a + b) / porMes.length;
      if (gastoEseMes > promedio * 1.3) {
        comportamientos.add(FinancialBehavior(
          titulo: 'Gastas más cuando ingresas más',
          mensaje:
              'En el mes con mayores ingresos tus gastos también subieron. '
              'Cuidado con el efecto "me lo merezco".',
        ));
      }
    }

    return comportamientos;
  }

  // ══════════════════════════════════════════════════════════
  // PASO 8: Fugas (mes actual)
  // ══════════════════════════════════════════════════════════
  List<MoneyLeak> _detectarFugas(
    List<Movimiento> movimientosMes,
    double ingresos,
  ) {
    if (ingresos == 0) return [];

    final Map<String, double> porCategoria = {};
    for (final m in movimientosMes) {
      if (m.tipo == 'gasto' && !m.esDeuda) {
        porCategoria[m.categoria] =
            (porCategoria[m.categoria] ?? 0) + m.valor;
      }
    }

    return porCategoria.entries
        .where((e) => e.value / ingresos > 0.30)
        .map((e) => MoneyLeak(
              categoria: e.key,
              porcentaje: e.value / ingresos,
              mensaje:
                  'Tus gastos en ${e.key} representan '
                  '${((e.value / ingresos) * 100).toStringAsFixed(1)}% '
                  'de tus ingresos este mes.',
            ))
        .toList();
  }

  // ══════════════════════════════════════════════════════════
  // PASO 9: Score financiero
  // ══════════════════════════════════════════════════════════
  int _calcularScore(FlujoMensual flujo) {
    if (flujo.ingresos == 0) return 0;

    int score = 0;

    // Factor 1: gastos variables (25pts)
    final rv = flujo.ingresos > 0
        ? flujo.gastosVariables / flujo.ingresos
        : 1.0;
    if (rv <= 0.3) score += 25;
    else if (rv <= 0.5) score += 18;
    else if (rv <= 0.7) score += 10;
    else score += 2;

    // Factor 2: nivel de deuda (25pts)
    if (flujo.ratioDeuda == 0) score += 25;
    else if (flujo.ratioDeuda <= 0.3) score += 18;
    else if (flujo.ratioDeuda <= 0.6) score += 10;
    else score += 3;

    // Factor 3: disponible neto (25pts)
    final rd = flujo.ingresos > 0
        ? flujo.disponibleNeto / flujo.ingresos
        : 0.0;
    if (rd > 0.3) score += 25;
    else if (rd > 0.15) score += 18;
    else if (rd > 0) score += 10;
    else score += 2;

    // Factor 4: cobertura gastos fijos (25pts)
    final cobertura = flujo.ingresos > 0
        ? flujo.gastosFijos / flujo.ingresos
        : 1.0;
    if (cobertura <= 0.3) score += 25;
    else if (cobertura <= 0.5) score += 18;
    else if (cobertura <= 0.7) score += 10;
    else score += 2;

    return score.clamp(0, 100);
  }

  // ══════════════════════════════════════════════════════════
  // PASO 10: Contexto IA
  // ══════════════════════════════════════════════════════════
  String _construirContextoIA({
    required FlujoMensual flujo,
    required ModoFinanciero modo,
    required PlanPago planPago,
    required FinancialDistribution distribucion,
    required FinancialProjection proyeccion,
    required int score,
  }) {
    final buf = StringBuffer();

    buf.writeln('SITUACIÓN FINANCIERA REAL DE JUAN — ${DateTime.now().month}/${DateTime.now().year}');
    buf.writeln('');
    buf.writeln('MODO ACTUAL: ${modo.label} ${modo.emoji}');
    buf.writeln('${modo.descripcion}');
    buf.writeln('');
    buf.writeln('FLUJO DEL MES:');
    buf.writeln('- Ingresos: \$${flujo.ingresos.toStringAsFixed(0)}');
    buf.writeln('- Gastos fijos: \$${flujo.gastosFijos.toStringAsFixed(0)}');
    buf.writeln('- Gastos variables: \$${flujo.gastosVariables.toStringAsFixed(0)}');
    buf.writeln('- Cuotas de deuda: \$${flujo.cuotasDeuda.toStringAsFixed(0)}');
    buf.writeln('- Disponible neto: \$${flujo.disponibleNeto.toStringAsFixed(0)}');
    buf.writeln('- Disponible para atacar deuda: \$${flujo.disponibleParaDeuda.toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('DEUDAS:');
    buf.writeln('- Saldo total real: \$${flujo.totalDeudaReal.toStringAsFixed(0)}');
    if (planPago.tieneDeudas) {
      buf.writeln('- Meses para liberarse: ${planPago.mesesParaLiberarse}');
      buf.writeln('- Fecha estimada de libertad: ${planPago.fechaLiberacion != null ? '${planPago.fechaLiberacion!.month}/${planPago.fechaLiberacion!.year}' : 'N/A'}');
      buf.writeln('- Estrategia: ${planPago.estrategia}');
      if (planPago.detallePorDeuda.isNotEmpty) {
        buf.writeln('- Deuda prioritaria: ${planPago.detallePorDeuda.first.acreedor}');
      }
    } else {
      buf.writeln('- Sin deudas activas');
    }
    buf.writeln('');
    buf.writeln('DISTRIBUCIÓN RECOMENDADA:');
    buf.writeln('- Fase: ${distribucion.fase}');
    buf.writeln('- Para deuda: \$${distribucion.montoDeuda.toStringAsFixed(0)} (${(distribucion.porcentajeDeuda * 100).toStringAsFixed(0)}%)');
    buf.writeln('- Para fondo: \$${distribucion.montoFondo.toStringAsFixed(0)} (${(distribucion.porcentajeFondo * 100).toStringAsFixed(0)}%)');
    buf.writeln('- Para metas: \$${distribucion.montoMetas.toStringAsFixed(0)} (${(distribucion.porcentajeMetas * 100).toStringAsFixed(0)}%)');
    buf.writeln('');
    buf.writeln('PROYECCIÓN:');
    buf.writeln('- Ahorro mensual estimado: \$${proyeccion.ahorroMensual.toStringAsFixed(0)}');
    buf.writeln('- Ahorro a 12 meses: \$${proyeccion.ahorro12Meses.toStringAsFixed(0)}');
    buf.writeln('');
    buf.writeln('SCORE FINANCIERO: $score/100');
    buf.writeln('FONDO DE EMERGENCIA IDEAL: \$${flujo.fondoEmergenciaIdeal.toStringAsFixed(0)}');

    return buf.toString();
  }

  // ══════════════════════════════════════════════════════════
  // Helpers privados
  // ══════════════════════════════════════════════════════════
  Map<String, String> _evaluarSalud(FlujoMensual flujo) {
    if (flujo.ingresos == 0) {
      return {'estado': 'CRÍTICO', 'mensaje': 'No hay ingresos registrados'};
    }
    if (flujo.ratioGastoOperativo > 1) {
      return {'estado': 'CRÍTICO', 'mensaje': 'Gastas más de lo que ingresas'};
    }
    if (flujo.ratioGastoOperativo > 0.85) {
      return {'estado': 'RIESGO', 'mensaje': 'Gastos muy cerca de los ingresos'};
    }
    if (flujo.ratioGastoOperativo > 0.65) {
      return {'estado': 'AJUSTADO', 'mensaje': 'Margen de ahorro limitado'};
    }
    return {'estado': 'SALUDABLE', 'mensaje': 'Buen control financiero'};
  }
}
