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
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
        color = Colors.red;
        break;
      case ModoFinanciero.ataque:
        color = Colors.orange;
        break;
      case ModoFinanciero.libertad:
        color = Colors.green;
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

          // En modo ataque — mostrar el número clave: fecha de libertad
          if (modo == ModoFinanciero.ataque &&
              result.planPago.mesesParaLiberarse > 0) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildBannerDato(
                  'Deuda total',
                  _fmt.format(flujo.totalDeudaReal),
                  Colors.red,
                ),
                _buildBannerDato(
                  'Disponible para atacar',
                  _fmt.format(flujo.disponibleParaDeuda),
                  Colors.orange,
                ),
                _buildBannerDato(
                  'Libre en',
                  '${result.planPago.mesesParaLiberarse} meses',
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.credit_card_outlined, size: 16),
                label: const Text('Ver plan de deudas'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
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
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_rounded,
                      color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tus gastos fijos + cuotas de deuda superan tus ingresos. '
                      'Reducir un gasto fijo es urgente.',
                      style: const TextStyle(fontSize: 12, color: Colors.red),
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
                  Colors.green,
                ),
                _buildBannerDato(
                  'Fondo ideal',
                  _fmt.format(flujo.fondoEmergenciaIdeal),
                  Colors.blue,
                ),
                _buildBannerDato(
                  'Para invertir',
                  _fmt.format(flujo.disponibleParaAhorro),
                  Colors.teal,
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
      // Riesgos — lo más urgente
      DashboardSectionCard(
        titulo: 'Riesgos críticos',
        icono: Icons.warning_amber_rounded,
        inicialmenteExpandido: true,
        children: result.riesgos.map(_buildRiesgo).toList(),
      ),
      const SizedBox(height: 12),

      // Recomendaciones de emergencia
      DashboardSectionCard(
        titulo: 'Qué hacer ahora',
        icono: Icons.bolt_outlined,
        inicialmenteExpandido: true,
        children: result.recomendaciones.map(_buildRecomendacion).toList(),
      ),
      const SizedBox(height: 12),

      // Flujo del mes
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
      // Plan de distribución — lo más accionable
      DashboardSectionCard(
        titulo: 'Plan del mes',
        icono: Icons.account_balance_wallet_outlined,
        inicialmenteExpandido: true,
        children: [_buildDistribucion(result.distribucion)],
      ),
      const SizedBox(height: 12),

      // Insights relevantes
      if (result.insights.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Insights',
          icono: Icons.lightbulb_outline,
          children: result.insights.map(_buildInsight).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Recomendaciones
      DashboardSectionCard(
        titulo: 'Recomendaciones',
        icono: Icons.recommend_outlined,
        children: result.recomendaciones.map(_buildRecomendacion).toList(),
      ),
      const SizedBox(height: 12),

      // Fugas de dinero — enemy of debt payoff
      if (result.fugas.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Fugas de dinero',
          icono: Icons.money_off,
          children: result.fugas.map(_buildFuga).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Estrategias
      if (result.estrategias.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Estrategias',
          icono: Icons.flag_outlined,
          children: result.estrategias.map(_buildEstrategia).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Gráficas — colapsadas por defecto en modo ataque
      DashboardSectionCard(
        titulo: 'Gráficas financieras',
        icono: Icons.bar_chart,
        inicialmenteExpandido: false,
        children: [
          DashboardChartsCard(financialScore: result.scoreFinanciero),
        ],
      ),
      const SizedBox(height: 12),

      // Proyección
      DashboardSectionCard(
        titulo: 'Proyección a 12 meses',
        icono: Icons.show_chart,
        inicialmenteExpandido: false,
        children: [_buildProyeccion(result.proyeccion)],
      ),
      const SizedBox(height: 12),

      // Comportamiento — colapsado
      if (result.comportamiento.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Tu comportamiento financiero',
          icono: Icons.psychology_outlined,
          inicialmenteExpandido: false,
          children: result.comportamiento.map(_buildComportamiento).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Riesgos — colapsados
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
      // Proyección — ahora sí importa el ahorro
      DashboardSectionCard(
        titulo: 'Tu proyección de crecimiento',
        icono: Icons.show_chart,
        inicialmenteExpandido: true,
        children: [_buildProyeccion(result.proyeccion)],
      ),
      const SizedBox(height: 12),

      // Plan de distribución — ahora para metas e inversión
      DashboardSectionCard(
        titulo: 'Plan del mes',
        icono: Icons.account_balance_wallet_outlined,
        inicialmenteExpandido: true,
        children: [_buildDistribucion(result.distribucion)],
      ),
      const SizedBox(height: 12),

      // Estrategias — ahora de inversión
      if (result.estrategias.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Estrategias de crecimiento',
          icono: Icons.flag_outlined,
          children: result.estrategias.map(_buildEstrategia).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Insights
      if (result.insights.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Insights',
          icono: Icons.lightbulb_outline,
          children: result.insights.map(_buildInsight).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Gráficas
      DashboardSectionCard(
        titulo: 'Gráficas financieras',
        icono: Icons.bar_chart,
        children: [
          DashboardChartsCard(financialScore: result.scoreFinanciero),
        ],
      ),
      const SizedBox(height: 12),

      // Comportamiento
      if (result.comportamiento.isNotEmpty) ...[
        DashboardSectionCard(
          titulo: 'Tu comportamiento financiero',
          icono: Icons.psychology_outlined,
          inicialmenteExpandido: false,
          children: result.comportamiento.map(_buildComportamiento).toList(),
        ),
        const SizedBox(height: 12),
      ],

      // Fugas
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
        _buildFilaFlujo('Ingresos', _fmt.format(flujo.ingresos), Colors.green),
        _buildFilaFlujo(
            'Gastos fijos', _fmt.format(flujo.gastosFijos), Colors.red),
        _buildFilaFlujo(
            'Gastos variables', _fmt.format(flujo.gastosVariables), Colors.orange),
        _buildFilaFlujo(
            'Cuotas deuda', _fmt.format(flujo.cuotasDeuda), Colors.red),
        const Divider(height: 16),
        _buildFilaFlujo(
          'Disponible neto',
          _fmt.format(flujo.disponibleNeto),
          flujo.disponibleNeto >= 0 ? Colors.green : Colors.red,
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
    final color = esAlerta ? Colors.orange : Colors.green;
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
          const Icon(Icons.leak_add, color: Colors.redAccent, size: 20),
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
                color: Colors.redAccent, fontWeight: FontWeight.bold),
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
          const Icon(Icons.insights, color: Colors.blueAccent, size: 20),
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
          const Icon(Icons.flag, color: Colors.teal, size: 20),
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

  Widget _buildProyeccion(FinancialProjection p) {
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
    Color colorFase;
    IconData iconoFase;

    switch (d.fase) {
      case 'CRITICA':
        colorFase = Colors.red;
        iconoFase = Icons.warning_rounded;
        break;
      case 'MODERADA':
        colorFase = Colors.orange;
        iconoFase = Icons.balance;
        break;
      case 'ESTABLE':
        colorFase = Colors.green;
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
            Colors.red,
          ),
        _buildItemDistribucion(
          '🛡️ Fondo emergencia',
          '${(d.porcentajeFondo * 100).toStringAsFixed(0)}%',
          _fmt.format(d.montoFondo),
          Colors.blue,
        ),
        _buildItemDistribucion(
          '🎯 Metas / inversión',
          '${(d.porcentajeMetas * 100).toStringAsFixed(0)}%',
          _fmt.format(d.montoMetas),
          Colors.green,
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
