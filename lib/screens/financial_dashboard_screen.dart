import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/master_financial_brain.dart';
import '../models/master_financial_result.dart';
import '../models/modo_financiero.dart';
import '../models/financial_distribution.dart';
import '../models/financial_projection.dart';
import '../models/financial_insight.dart';
import '../models/financial_recommendation.dart';
import '../models/financial_risk.dart';
import '../models/financial_strategy.dart';
import '../models/financial_behavior.dart';
import '../models/money_leak.dart';
import '../widgets/dashboard_score_card.dart';
import '../widgets/dashboard_section_card.dart';
import '../widgets/dashboard_risk_chip.dart';
import '../widgets/dashboard_charts_card.dart';
import '../screens/chat_ia_screen.dart';
import '../screens/deudas_screen.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';

class FinancialDashboardScreen extends StatefulWidget {
  const FinancialDashboardScreen({super.key});

  @override
  State<FinancialDashboardScreen> createState() =>
      _FinancialDashboardScreenState();
}

class _FinancialDashboardScreenState
    extends State<FinancialDashboardScreen> {
  final _brain = MasterFinancialBrain.instance;

  static final _fmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  MasterFinancialResult? _result;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool forzar = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final result = await _brain.analizar(forzar: forzar);
      setState(() {
        _result = result;
        _cargando = false;
      });
      NotificationService.analizarYNotificar();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el análisis financiero.';
        _cargando = false;
      });
    }
  }

  // ── AppBar ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final modo = _result?.modo ?? ModoFinanciero.sinDatos;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(modo.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              modo.label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Asesor IA',
              onPressed: _abrirChatIA,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => _cargar(forzar: true),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  void _abrirChatIA() {
    if (_result == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatIAScreen(result: _result!),
    );
  }

  // ── Body ──────────────────────────────────────────────────
  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.gasto),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _cargar(forzar: true),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final result = _result!;

    // Sin datos — pantalla de bienvenida
    if (result.modo == ModoFinanciero.sinDatos) {
      return _buildSinDatos();
    }

    return RefreshIndicator(
      onRefresh: () => _cargar(forzar: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner de modo — lo más importante arriba
          _buildBannerModo(result),
          const SizedBox(height: 16),

          // Score
          DashboardScoreCard(score: result.scoreFinanciero),
          const SizedBox(height: 12),

          // Contenido según modo
          ..._buildContenidoPorModo(result),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Banner de modo ────────────────────────────────────────
  Widget _buildBannerModo(MasterFinancialResult result) {
    final modo = result.modo;
    final flujo = result.flujoMensual;

    Color color;
    switch (modo) {
      case ModoFinanciero.supervivencia:
        color = AppColors.gasto;
        break;
      case ModoFinanciero.ataque:
        color = AppColors.deuda;
        break;
      case ModoFinanciero.libertad:
        color = AppColors.ingreso;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(modo.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                modo.label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            modo.descripcion,
            style: const TextStyle(fontSize: 13),
          ),

          // En modo ataque — la deuda es real siempre. Pero "disponible
          // para atacar" y "libre en X" dependen del excedente, que se
          // infla sin gastos. Solo los mostramos con datos creíbles.
          if (modo == ModoFinanciero.ataque) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (result.distribucion.faseTipada ==
                FaseFinanciera.datosInsuficientes) ...[
              // Sin datos creíbles: solo la deuda real + aviso honesto.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildBannerDato(
                    'Deuda total',
                    _fmt.format(flujo.totalDeudaReal),
                    AppColors.gasto,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Text(
                        'Registra tus gastos del mes para calcular cuánto '
                        'puedes destinar a atacar la deuda.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Con datos creíbles: el plan completo.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBannerDato(
                    'Deuda total',
                    _fmt.format(flujo.totalDeudaReal),
                    AppColors.gasto,
                  ),
                  _buildBannerDato(
                    'Disponible para atacar',
                    _fmt.format(flujo.disponibleParaDeuda),
                    AppColors.deuda,
                  ),
                  _buildBannerDato(
                    'Libre en',
                    result.planPago.mesesParaLiberarse == 1
                        ? '1 mes'
                        : '${result.planPago.mesesParaLiberarse} meses',
                    AppColors.ingreso,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.credit_card_outlined, size: 16),
                label: const Text('Ver plan de deudas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deuda,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DeudasScreen(),
                    ),
                  ).then((_) => _cargar(forzar: true));
                },
              ),
            ),
          ],

          // En modo supervivencia — acción urgente
          if (modo == ModoFinanciero.supervivencia) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.gasto.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: AppColors.gasto, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tus gastos fijos + cuotas de deuda superan tus ingresos. '
                      'Reducir un gasto fijo es urgente.',
                      style: const TextStyle(fontSize: 12, color: AppColors.gasto),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // En modo libertad — celebrar
          if (modo == ModoFinanciero.libertad) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBannerDato(
                  'Disponible',
                  _fmt.format(flujo.disponibleNeto),
                  AppColors.ingreso,
                ),
                _buildBannerDato(
                  'Fondo ideal',
                  _fmt.format(flujo.fondoEmergenciaIdeal),
                  AppColors.fondo,
                ),
                _buildBannerDato(
                  'Para invertir',
                  _fmt.format(flujo.disponibleParaAhorro),
                  AppColors.inversion,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBannerDato(String label, String valor, Color color) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ── Contenido por modo ────────────────────────────────────
  List<Widget> _buildContenidoPorModo(MasterFinancialResult result) {
    switch (result.modo) {
      case ModoFinanciero.supervivencia:
        return _contenidoSupervivencia(result);
      case ModoFinanciero.ataque:
        return _contenidoAtaque(result);
      case ModoFinanciero.libertad:
        return _contenidoLibertad(result);
      default:
        return [];
    }
  }

  // ── MODO SUPERVIVENCIA — solo lo urgente ──────────────────
  List<Widget> _contenidoSupervivencia(MasterFinancialResult result) {
    return [
      DashboardSectionCard(
        titulo: 'Riesgos críticos',
        icono: Icons.warning_amber_rounded,
        inicialmenteExpandido: true,
        children: result.riesgos.map(_buildRiesgo).toList(),
      ),
      const SizedBox(height: 12),
      DashboardSectionCard(
        titulo: 'Qué hacer ahora',
        icono: Icons.bolt_outlined,
        inicialmenteExpandido: true,
        children: result.recomendaciones.map(_buildRecomendacion).toList(),
      ),
      const SizedBox(height: 12),
      DashboardSectionCard(
        titulo: 'Tu flujo este mes',
        icono: Icons.account_balance_wallet_outlined,
        children: [_buildFlujoMensual(result)],
      ),
    ];
  }

  // ── MODO ATAQUE — enfoque en deuda ────────────────────────
  List<Widget> _contenidoAtaque(MasterFinancialResult result) {
    return [
      DashboardSectionCard(
        titulo: 'Plan del mes',
        icono: Icons.account_balance_wallet_outlined,
        inicialmenteExpandido: true,
        children: [_buildDistribucion(result.distribucion)],
      ),
      const SizedBox(height: 12),
      if (result.insights.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Insights',
          icono: Icons.lightbulb_outline,
          children: result.insights.map(_buildInsight).toList(),
        ),
        const SizedBox(height: 12),
      ],
      DashboardSectionCard(
        titulo: 'Recomendaciones',
        icono: Icons.recommend_outlined,
        children: result.recomendaciones.map(_buildRecomendacion).toList(),
      ),
      const SizedBox(height: 12),
      if (result.fugas.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Fugas de dinero',
          icono: Icons.money_off,
          children: result.fugas.map(_buildFuga).toList(),
        ),
        const SizedBox(height: 12),
      ],
      if (result.estrategias.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Estrategias',
          icono: Icons.flag_outlined,
          children: result.estrategias.map(_buildEstrategia).toList(),
        ),
        const SizedBox(height: 12),
      ],
      DashboardSectionCard(
        titulo: 'Gráficas financieras',
        icono: Icons.bar_chart,
        inicialmenteExpandido: false,
        children: [
          DashboardChartsCard(financialScore: result.scoreFinanciero),
        ],
      ),
      const SizedBox(height: 12),
      DashboardSectionCard(
        titulo: 'Proyección a 12 meses',
        icono: Icons.show_chart,
        inicialmenteExpandido: false,
        children: [
          _buildProyeccion(
            result.proyeccion,
            datosConfiables: result.distribucion.faseTipada !=
                FaseFinanciera.datosInsuficientes,
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (result.comportamiento.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Tu comportamiento financiero',
          icono: Icons.psychology_outlined,
          inicialmenteExpandido: false,
          children: result.comportamiento.map(_buildComportamiento).toList(),
        ),
        const SizedBox(height: 12),
      ],
      DashboardSectionCard(
        titulo: 'Riesgos',
        icono: Icons.warning_amber_rounded,
        inicialmenteExpandido: false,
        children: result.riesgos.map(_buildRiesgo).toList(),
      ),
    ];
  }

  // ── MODO LIBERTAD — enfoque en patrimonio ─────────────────
  List<Widget> _contenidoLibertad(MasterFinancialResult result) {
    return [
      DashboardSectionCard(
        titulo: 'Tu proyección de crecimiento',
        icono: Icons.show_chart,
        inicialmenteExpandido: true,
        children: [
          _buildProyeccion(
            result.proyeccion,
            datosConfiables: result.distribucion.faseTipada !=
                FaseFinanciera.datosInsuficientes,
          ),
        ],
      ),
      const SizedBox(height: 12),
      DashboardSectionCard(
        titulo: 'Plan del mes',
        icono: Icons.account_balance_wallet_outlined,
        inicialmenteExpandido: true,
        children: [_buildDistribucion(result.distribucion)],
      ),
      const SizedBox(height: 12),
      if (result.estrategias.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Estrategias de crecimiento',
          icono: Icons.flag_outlined,
          children: result.estrategias.map(_buildEstrategia).toList(),
        ),
        const SizedBox(height: 12),
      ],
      if (result.insights.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Insights',
          icono: Icons.lightbulb_outline,
          children: result.insights.map(_buildInsight).toList(),
        ),
        const SizedBox(height: 12),
      ],
      DashboardSectionCard(
        titulo: 'Gráficas financieras',
        icono: Icons.bar_chart,
        children: [
          DashboardChartsCard(financialScore: result.scoreFinanciero),
        ],
      ),
      const SizedBox(height: 12),
      if (result.comportamiento.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Tu comportamiento financiero',
          icono: Icons.psychology_outlined,
          inicialmenteExpandido: false,
          children: result.comportamiento.map(_buildComportamiento).toList(),
        ),
        const SizedBox(height: 12),
      ],
      if (result.fugas.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Fugas de dinero',
          icono: Icons.money_off,
          inicialmenteExpandido: false,
          children: result.fugas.map(_buildFuga).toList(),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }

  // ── Estado vacío ──────────────────────────────────────────
  Widget _buildSinDatos() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'Aún sin datos este mes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tus ingresos y gastos del mes para que '
              'el sistema calcule tu plan financiero.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 8),
            Text(
              'También registra tus deudas reales en la pantalla 💳 '
              'para ver tu fecha de libertad financiera.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ── Flujo mensual (para supervivencia) ────────────────────
  Widget _buildFlujoMensual(MasterFinancialResult result) {
    final flujo = result.flujoMensual;
    return Column(
      children: [
        _buildFilaFlujo('Ingresos', _fmt.format(flujo.ingresos), AppColors.ingreso),
        _buildFilaFlujo(
            'Gastos fijos', _fmt.format(flujo.gastosFijos), AppColors.gasto),
        _buildFilaFlujo(
            'Gastos variables', _fmt.format(flujo.gastosVariables), AppColors.deuda),
        _buildFilaFlujo(
            'Cuotas deuda', _fmt.format(flujo.cuotasDeuda), AppColors.gasto),
        const Divider(height: 16),
        _buildFilaFlujo(
          'Disponible neto',
          _fmt.format(flujo.disponibleNeto),
          flujo.disponibleNeto >= 0 ? AppColors.ingreso : AppColors.gasto,
          destacado: true,
        ),
      ],
    );
  }

  Widget _buildFilaFlujo(
    String label,
    String valor,
    Color color, {
    bool destacado = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Builders reutilizables ────────────────────────────────

  Widget _buildRiesgo(FinancialRisk riesgo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DashboardRiskChip(risk: riesgo),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(riesgo.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(riesgo.descripcion,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsight(FinancialInsight insight) {
    final esAlerta = insight.nivel == 'alerta';
    final color = esAlerta ? AppColors.deuda : AppColors.ingreso;
    final icono =
        esAlerta ? Icons.warning_amber : Icons.check_circle_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(insight.mensaje,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecomendacion(FinancialRecommendation rec) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rec.titulo,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(rec.descripcion, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            rec.impacto,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }

  Widget _buildFuga(MoneyLeak fuga) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.leak_add, color: AppColors.gasto, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fuga.categoria,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(fuga.mensaje,
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Text(
            '${(fuga.porcentaje * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
                color: AppColors.gasto, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildComportamiento(FinancialBehavior b) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.insights, color: AppColors.fondo, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(b.mensaje, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEstrategia(FinancialStrategy e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag, color: AppColors.inversion, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.titulo,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(e.descripcion, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProyeccion(FinancialProjection p, {bool datosConfiables = true}) {
    // Sin datos creíbles la proyección se infla (ahorro irreal). En vez de
    // afirmar un número falso, lo decimos honestamente.
    if (!datosConfiables) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.show_chart, color: Colors.grey.shade500, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Registra tus gastos del mes para proyectar tu ahorro a '
                'futuro de forma realista.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(p.mensaje, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        _buildFila('Ingreso promedio', _fmt.format(p.ingresoPromedio)),
        _buildFila('Gasto promedio', _fmt.format(p.gastoPromedio)),
        _buildFila('Ahorro mensual estimado', _fmt.format(p.ahorroMensual)),
        _buildFila(
          'Ahorro a 12 meses',
          _fmt.format(p.ahorro12Meses),
          destacado: true,
        ),
      ],
    );
  }

  Widget _buildFila(String label, String valor, {bool destacado = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  destacado ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: destacado
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistribucion(FinancialDistribution d) {
    // Datos insuficientes: no mostramos un plan sobre un excedente irreal.
    // Pedimos honestamente los gastos que faltan.
    if (d.faseTipada == FaseFinanciera.datosInsuficientes) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.fondo.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.fondo.withValues(alpha: 0.20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_outlined,
                    color: Colors.grey.shade600, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Faltan tus gastos del mes',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              d.mensaje,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Registrar gastos'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      );
    }

    Color colorFase;
    IconData iconoFase;

    switch (d.fase) {
      case 'CRITICA':
        colorFase = AppColors.gasto;
        iconoFase = Icons.warning_rounded;
        break;
      case 'MODERADA':
        colorFase = AppColors.deuda;
        iconoFase = Icons.balance;
        break;
      case 'ESTABLE':
        colorFase = AppColors.ingreso;
        iconoFase = Icons.trending_up;
        break;
      default:
        colorFase = Colors.grey;
        iconoFase = Icons.info_outline;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorFase.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: colorFase.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(iconoFase, color: colorFase, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fase ${d.fase}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: colorFase,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(d.descripcionFase,
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        _buildFila('Ingresos', _fmt.format(d.ingresos)),
        _buildFila('Gastos fijos', _fmt.format(d.gastosFijos)),
        _buildFila('Excedente disponible', _fmt.format(d.excedenteReal),
            destacado: true),

        const SizedBox(height: 14),
        const Text(
          'Distribución del excedente',
          style:
              TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 10),

        if (d.montoDeuda > 0)
          _buildItemDistribucion(
            '📉 Deuda',
            '${(d.porcentajeDeuda * 100).toStringAsFixed(0)}%',
            _fmt.format(d.montoDeuda),
            AppColors.gasto,
          ),
        _buildItemDistribucion(
          '🛡️ Fondo emergencia',
          '${(d.porcentajeFondo * 100).toStringAsFixed(0)}%',
          _fmt.format(d.montoFondo),
          AppColors.fondo,
        ),
        _buildItemDistribucion(
          '🎯 Metas / inversión',
          '${(d.porcentajeMetas * 100).toStringAsFixed(0)}%',
          _fmt.format(d.montoMetas),
          AppColors.ingreso,
        ),

        if (d.mesesParaSalirDeDeuda > 0) ...[
          const SizedBox(height: 12),
          _buildFila(
              '📉 Libre de deuda en', '${d.mesesParaSalirDeDeuda} meses'),
        ],
        if (d.mesesParaFondoCompleto > 0)
          _buildFila(
              '🛡️ Fondo completo en', '${d.mesesParaFondoCompleto} meses'),

        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(d.mensaje,
              style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildItemDistribucion(
    String label,
    String porcentaje,
    String monto,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (double.tryParse(
                                porcentaje.replaceAll('%', '')) ??
                            0) /
                        100,
                    minHeight: 6,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(porcentaje,
                  style: TextStyle(
                      fontSize: 12,
                      color: color,
                      fontWeight: FontWeight.bold)),
              Text(monto,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
