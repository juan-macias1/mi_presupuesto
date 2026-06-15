import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/master_financial_brain.dart';
import '../models/master_financial_result.dart';
import '../models/cascada_mensual.dart';
import '../models/modo_financiero.dart';
import '../models/financial_distribution.dart';
import '../models/financial_projection.dart';
import '../models/financial_insight.dart';
import '../models/financial_recommendation.dart';
import '../models/financial_risk.dart';
import '../models/financial_strategy.dart';
import '../models/financial_behavior.dart';
import '../models/money_leak.dart';
import '../widgets/dashboard_section_card.dart';
import '../widgets/dashboard_risk_chip.dart';
import '../widgets/dashboard_charts_card.dart';
import '../screens/chat_ia_screen.dart';
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
          // Zona foco — hero + contexto
          _buildBannerModo(result),

          // Score como línea fina, solo cuando es real (>= 0)
          if (result.scoreFinanciero >= 0) ...[
            const SizedBox(height: 14),
            _buildScoreLinea(result.scoreFinanciero),
          ],

          const SizedBox(height: 16),
          ..._buildContenidoPorModo(result),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Banner de modo ────────────────────────────────────────
  // ── Zona foco — hero + contexto ───────────────────────────
  Widget _buildBannerModo(MasterFinancialResult result) {
    final sinDatos = result.distribucion.faseTipada ==
        FaseFinanciera.datosInsuficientes;

    switch (result.modo) {
      case ModoFinanciero.ataque:
        return sinDatos
            ? _focoAtaqueSinDatos(result)
            : _focoAtaqueConDatos(result);
      case ModoFinanciero.supervivencia:
        return _focoSupervivencia(result);
      case ModoFinanciero.libertad:
        return sinDatos
            ? _focoLibertadSinDatos(result)
            : _focoLibertadConDatos(result);
      default:
        return const SizedBox.shrink();
    }
  }

  // Ataque · con datos: la fecha de libertad como protagonista.
  Widget _focoAtaqueConDatos(MasterFinancialResult result) {
    final flujo = result.flujoMensual;
    final meses = result.planPago.mesesParaLiberarse;
    return Column(
      children: [
        _hero(
          fondo: AppColors.primary,
          modo: result.modo,
          eyebrowInline: 'libre en',
          numero: meses == 1 ? '1 mes' : '$meses meses',
          subtitulo: '${_fechaLibertad(meses)} · si mantengo el ritmo',
        ),
        _focoTarjetas(
          _focoTarjeta(
              'Debo', _fmt.format(flujo.totalDeudaReal), AppColors.gasto),
          _focoTarjeta('Para atacar',
              _fmt.format(flujo.disponibleParaDeuda), AppColors.ingreso),
        ),
      ],
    );
  }

  // Ataque · sin datos creíbles: la deuda real, nunca una fecha inventada.
  Widget _focoAtaqueSinDatos(MasterFinancialResult result) {
    final flujo = result.flujoMensual;
    return _hero(
      fondo: AppColors.primary,
      modo: result.modo,
      eyebrowLinea: 'Mi deuda hoy',
      numero: _fmt.format(flujo.totalDeudaReal),
      subtitulo: 'Registro mis gastos del mes y calculo mi fecha de libertad.',
    );
  }

  // Supervivencia: el déficit es real aunque falten gastos variables.
  Widget _focoSupervivencia(MasterFinancialResult result) {
    final flujo = result.flujoMensual;
    return _hero(
      fondo: AppColors.gasto,
      modo: result.modo,
      eyebrowLinea: 'Este mes me faltan',
      numero: _fmt.format(flujo.disponibleNeto.abs()),
      subtitulo: 'Mis gastos fijos y cuotas superan lo que entra. '
          'Bajar un gasto fijo es lo urgente.',
    );
  }

  // Libertad · con datos: sin deuda, foco en construir patrimonio.
  Widget _focoLibertadConDatos(MasterFinancialResult result) {
    final flujo = result.flujoMensual;
    return Column(
      children: [
        _hero(
          fondo: AppColors.primary,
          modo: result.modo,
          eyebrowInline: 'cada mes invierto',
          numero: _fmt.format(flujo.disponibleParaAhorro),
          subtitulo: 'Sin deudas. Construyo patrimonio.',
        ),
        _focoTarjetas(
          _focoTarjeta('Fondo ideal',
              _fmt.format(flujo.fondoEmergenciaIdeal), AppColors.fondo),
          _focoTarjeta(
              'Disponible', _fmt.format(flujo.disponibleNeto), AppColors.ingreso),
        ),
      ],
    );
  }

  // Libertad · sin datos: ya soy libre de deuda, pero no invento el ahorro.
  Widget _focoLibertadSinDatos(MasterFinancialResult result) {
    return _hero(
      fondo: AppColors.primary,
      modo: result.modo,
      eyebrowLinea: 'Sin deudas',
      numero: 'Libre',
      subtitulo: 'Registro mis gastos del mes para ver cuánto puedo invertir.',
    );
  }

  // ── Hero ──────────────────────────────────────────────────
  Widget _hero({
    required Color fondo,
    required ModoFinanciero modo,
    String? eyebrowInline,
    String? eyebrowLinea,
    required String numero,
    String? subtitulo,
  }) {
    final header =
        eyebrowInline == null ? modo.label : '${modo.label} · $eyebrowInline';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(modo.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  header,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          if (eyebrowLinea != null) ...[
            const SizedBox(height: 10),
            Text(
              eyebrowLinea,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 2),
          ] else
            const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              numero,
              style: const TextStyle(
                fontSize: 36,
                height: 1.05,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          if (subtitulo != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitulo,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Tarjetas de contexto (fuera del hero) ─────────────────
  Widget _focoTarjetas(Widget a, Widget b) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: a),
          const SizedBox(width: 10),
          Expanded(child: b),
        ],
      ),
    );
  }

  Widget _focoTarjeta(String label, String valor, Color colorValor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorValor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fechaLibertad(int meses) {
    const nombres = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final hoy = DateTime.now();
    final objetivo = DateTime(hoy.year, hoy.month + meses, 1);
    return '${nombres[objetivo.month - 1]} ${objetivo.year}';
  }

  // ── Score en línea fina ───────────────────────────────────
  Widget _buildScoreLinea(int score) {
    Color color;
    String etiqueta;
    if (score >= 80) {
      color = const Color(0xFF2E7D32);
      etiqueta = 'Excelente';
    } else if (score >= 60) {
      color = const Color(0xFF558B2F);
      etiqueta = 'Bueno';
    } else if (score >= 40) {
      color = const Color(0xFFEF6C00);
      etiqueta = 'Regular';
    } else {
      color = const Color(0xFFC62828);
      etiqueta = 'En riesgo';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Text(
            'Mi score',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$score · $etiqueta',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Contenido por modo — tres puertas ─────────────────────
  List<Widget> _buildContenidoPorModo(MasterFinancialResult result) {
    if (result.modo == ModoFinanciero.supervivencia) {
      return _puertasSupervivencia(result);
    }
    return _puertasNormal(result);
  }

  // Ataque y libertad: las tres puertas completas.
  List<Widget> _puertasNormal(MasterFinancialResult result) {
    final datosConfiables = result.distribucion.faseTipada !=
        FaseFinanciera.datosInsuficientes;

    // "Lo que hago": la cascada (plan prescriptivo) va arriba como
    // protagonista; la distribución del excedente queda debajo, como el
    // detalle. Con datos insuficientes no mostramos la cascada — la
    // distribución ya pide los gastos, no repetimos el mensaje.
    final hago = <Widget>[];
    if (datosConfiables) {
      hago.add(_buildCascada(result.cascada));
      hago.add(const SizedBox(height: 14));
      hago.add(const Divider(height: 1));
      hago.add(const SizedBox(height: 14));
      hago.add(_buildDistribucion(result.distribucion));
    } else {
      hago.add(_buildDistribucion(result.distribucion));
    }
    if (result.recomendaciones.isNotEmpty) {
      _agregarBloque(hago, 'Qué hacer',
          result.recomendaciones.map(_buildRecomendacion));
    }

    final estoy = <Widget>[];
    if (result.insights.isNotEmpty) {
      _agregarBloque(estoy, 'Insights', result.insights.map(_buildInsight));
    }
    if (result.riesgos.isNotEmpty) {
      _agregarBloque(estoy, 'Riesgos', result.riesgos.map(_buildRiesgo));
    }
    if (result.fugas.isNotEmpty) {
      _agregarBloque(estoy, 'Fugas de dinero', result.fugas.map(_buildFuga));
    }
    if (result.comportamiento.isNotEmpty) {
      _agregarBloque(estoy, 'Tu comportamiento',
          result.comportamiento.map(_buildComportamiento));
    }
    if (estoy.isEmpty) {
      estoy.add(_vacioPuerta('Registra tus gastos para ver tu diagnóstico.'));
    }

    final voy = <Widget>[
      _buildProyeccion(result.proyeccion, datosConfiables: datosConfiables),
    ];
    if (result.estrategias.isNotEmpty) {
      _agregarBloque(
          voy, 'Estrategias', result.estrategias.map(_buildEstrategia));
    }
    _agregarBloque(voy, 'Gráficas',
        [DashboardChartsCard(financialScore: result.scoreFinanciero)]);

    return [
      DashboardSectionCard(
        titulo: 'Lo que hago este mes',
        icono: Icons.account_balance_wallet_outlined,
        resumen: _resumenLoQueHago(result),
        inicialmenteExpandido: true,
        children: hago,
      ),
      const SizedBox(height: 10),
      DashboardSectionCard(
        titulo: 'Cómo estoy',
        icono: Icons.psychology_outlined,
        resumen: _resumenComoEstoy(result),
        inicialmenteExpandido: false,
        children: estoy,
      ),
      const SizedBox(height: 10),
      DashboardSectionCard(
        titulo: 'Hacia dónde voy',
        icono: Icons.show_chart,
        resumen: _resumenHaciaDonde(result),
        inicialmenteExpandido: false,
        children: voy,
      ),
    ];
  }

  // Supervivencia: solo lo urgente, dos puertas, ambas abiertas.
  List<Widget> _puertasSupervivencia(MasterFinancialResult result) {
    final hago = <Widget>[];
    if (result.recomendaciones.isNotEmpty) {
      hago.addAll(result.recomendaciones.map(_buildRecomendacion));
    } else {
      hago.add(_vacioPuerta('Reduce un gasto fijo para volver a flote.'));
    }

    final estoy = <Widget>[];
    if (result.riesgos.isNotEmpty) {
      _agregarBloque(
          estoy, 'Riesgos críticos', result.riesgos.map(_buildRiesgo));
    }
    _agregarBloque(estoy, 'Mi flujo este mes', [_buildFlujoMensual(result)]);
    if (result.fugas.isNotEmpty) {
      _agregarBloque(estoy, 'Fugas de dinero', result.fugas.map(_buildFuga));
    }

    return [
      DashboardSectionCard(
        titulo: 'Lo que hago este mes',
        icono: Icons.account_balance_wallet_outlined,
        resumen: 'Acciones urgentes',
        inicialmenteExpandido: true,
        children: hago,
      ),
      const SizedBox(height: 10),
      DashboardSectionCard(
        titulo: 'Cómo estoy',
        icono: Icons.psychology_outlined,
        resumen: _resumenComoEstoy(result),
        inicialmenteExpandido: true,
        children: estoy,
      ),
    ];
  }

  // ── Cascada de razonamiento — el plan PRESCRIPTIVO del mes ─
  // Reparte el ingreso EN ORDEN hasta el margen. Los renglones que no
  // aplican (p. ej. las cuotas cuando no hay deuda) no se muestran; los
  // destinos y el mensaje los decide el motor según el modo, no están
  // escritos a mano. Así la misma cascada se ve distinta en ataque y en
  // libertad.
  Widget _buildCascada(CascadaMensual c) {
    if (!c.datosSuficientes) return const SizedBox.shrink();

    final margenPositivo = c.margen > 0;
    final colorMargen = margenPositivo ? AppColors.primary : AppColors.gasto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ingreso — el punto de partida.
        _cascadaFila(
          'Me entra',
          _fmt.format(c.ingresos),
          color: AppColors.ingreso,
          resaltarValor: true,
        ),
        const Divider(height: 18),

        // Restas en orden — solo las que aplican.
        if (c.gastosFijos > 0)
          _cascadaFila('Pago lo fijo', '− ${_fmt.format(c.gastosFijos)}'),
        if (c.cuotasDeuda > 0)
          _cascadaFila('Pago mis cuotas', '− ${_fmt.format(c.cuotasDeuda)}'),
        if (c.pagatePrimero > 0)
          _cascadaFila(
            'Me pago primero',
            '− ${_fmt.format(c.pagatePrimero)}',
            sub: c.destinoPagatePrimero,
          ),
        if (c.subsistencia > 0)
          _cascadaFila(
            'Como y me muevo',
            '− ${_fmt.format(c.subsistencia)}',
            sub: 'comida y transporte',
          ),

        const SizedBox(height: 12),

        // Margen — lo que queda, destacado. Verde si sobra, rojo si falta.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorMargen.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorMargen.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      margenPositivo ? 'Me queda' : 'Me falta',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorMargen,
                      ),
                    ),
                    if (c.destinoMargen.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        c.destinoMargen,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorMargen.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _fmt.format(c.margen.abs()),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colorMargen,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (c.mensaje.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            c.mensaje,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    );
  }

  // Una fila del waterfall: etiqueta (con subtexto opcional) a la izquierda,
  // monto a la derecha.
  Widget _cascadaFila(
    String label,
    String valor, {
    String? sub,
    Color? color,
    bool resaltarValor = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14)),
                if (sub != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            valor,
            style: TextStyle(
              fontSize: resaltarValor ? 18 : 15,
              fontWeight: resaltarValor ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers de las puertas ────────────────────────────────
  void _agregarBloque(
    List<Widget> children,
    String label,
    Iterable<Widget> items,
  ) {
    if (children.isNotEmpty) {
      children.add(const SizedBox(height: 14));
      children.add(const Divider(height: 1));
      children.add(const SizedBox(height: 14));
    }
    children.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
    children.addAll(items);
  }

  Widget _vacioPuerta(String texto) {
    return Text(
      texto,
      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
    );
  }

  String _resumenLoQueHago(MasterFinancialResult result) {
    final d = result.distribucion;
    if (d.faseTipada == FaseFinanciera.datosInsuficientes) {
      return 'Faltan tus gastos del mes';
    }
    if (result.modo == ModoFinanciero.supervivencia) {
      return 'Acciones urgentes';
    }
    if (d.montoDeuda > 0) {
      return '${_fmt.format(d.montoDeuda)} a la deuda este mes';
    }
    return 'Fondo y metas en marcha';
  }

  String _resumenComoEstoy(MasterFinancialResult result) {
    final r = result.riesgos.length;
    final f = result.fugas.length;
    final partes = <String>[];
    if (r > 0) partes.add('$r ${r == 1 ? 'alerta' : 'alertas'}');
    if (f > 0) partes.add('$f ${f == 1 ? 'fuga' : 'fugas'}');
    if (partes.isEmpty) {
      return result.distribucion.faseTipada ==
              FaseFinanciera.datosInsuficientes
          ? 'Registra tus gastos para ver tu situación'
          : 'Sin alertas por ahora';
    }
    return partes.join(' · ');
  }

  String _resumenHaciaDonde(MasterFinancialResult result) {
    if (result.distribucion.faseTipada ==
        FaseFinanciera.datosInsuficientes) {
      return 'Proyección al registrar tus gastos';
    }
    return 'Ahorro ${_fmt.format(result.proyeccion.ahorro12Meses)} en 12 meses';
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
