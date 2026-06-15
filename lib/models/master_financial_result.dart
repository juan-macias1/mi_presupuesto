import 'flujo_mensual.dart';
import 'modo_financiero.dart';
import 'plan_pago.dart';
import 'financial_analysis.dart';
import 'financial_distribution.dart';
import 'financial_projection.dart';
import 'financial_recommendation.dart';
import 'financial_insight.dart';
import 'financial_risk.dart';
import 'financial_strategy.dart';
import 'financial_behavior.dart';
import 'money_leak.dart';
import 'cascada_mensual.dart';

/// MasterFinancialResult — el único objeto que consume la UI.
/// Contiene todo lo que necesita el dashboard, las notificaciones y Claude IA.
class MasterFinancialResult {
  // ── Núcleo ────────────────────────────────────────────────
  final FlujoMensual flujoMensual;
  final ModoFinanciero modo;

  // ── Motores existentes (compatibilidad total) ─────────────
  final FinancialAnalysis analysis;
  final FinancialDistribution distribucion;
  final FinancialProjection proyeccion;
  final PlanPago planPago;

  // ── Cascada de razonamiento (plan prescriptivo del mes) ───
  final CascadaMensual cascada;

  // ── Insights y recomendaciones ────────────────────────────
  final List<FinancialInsight> insights;
  final List<FinancialRecommendation> recomendaciones;
  final List<FinancialRisk> riesgos;
  final List<FinancialStrategy> estrategias;
  final List<FinancialBehavior> comportamiento;
  final List<MoneyLeak> fugas;

  // ── Score ─────────────────────────────────────────────────
  final int scoreFinanciero;

  // ── Contexto listo para Claude IA ────────────────────────
  final String contextoIA;

  const MasterFinancialResult({
    required this.flujoMensual,
    required this.modo,
    required this.analysis,
    required this.distribucion,
    required this.proyeccion,
    required this.planPago,
    required this.cascada,
    required this.insights,
    required this.recomendaciones,
    required this.riesgos,
    required this.estrategias,
    required this.comportamiento,
    required this.fugas,
    required this.scoreFinanciero,
    required this.contextoIA,
  });

  // ── Factory vacío para estado inicial ────────────────────
  factory MasterFinancialResult.empty() {
    final flujo = FlujoMensual.empty();
    return MasterFinancialResult(
      flujoMensual: flujo,
      modo: ModoFinanciero.sinDatos,
      analysis: FinancialAnalysis.empty(),
      distribucion: FinancialDistribution.empty(),
      proyeccion: FinancialProjection.empty(),
      planPago: PlanPago.sinDeudas(),
      cascada: CascadaMensual.empty(),
      insights: [],
      recomendaciones: [],
      riesgos: [],
      estrategias: [],
      comportamiento: [],
      fugas: [],
      scoreFinanciero: 0,
      contextoIA: 'Sin datos registrados aún.',
    );
  }

  // ── Getters de conveniencia para la UI ───────────────────
  bool get tieneDatos => modo != ModoFinanciero.sinDatos;
  bool get esModoAtaque => modo == ModoFinanciero.ataque;
  bool get esModoLibertad => modo == ModoFinanciero.libertad;
  bool get esModoSupervivencia => modo == ModoFinanciero.supervivencia;

  /// Meses restantes para quedar libre de deudas
  int get mesesParaLibertad => planPago.mesesParaLiberarse;

  /// true si hay alertas críticas que mostrar
  bool get tieneAlertas =>
      riesgos.any((r) => r.nivel == 'critico' || r.nivel == 'alto');

  @override
  String toString() =>
      'MasterFinancialResult(modo: ${modo.label}, score: $scoreFinanciero)';
}
