import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/chart_engine.dart';
import '../theme/app_colors.dart';

/// DashboardChartsCard — gráficas del dashboard, rediseñadas.
///
/// Cambios clave del rediseño:
/// - Ingresos vs gastos: línea de tendencia compacta (no barras gigantes
///   que se desbordaban). Con un solo mes, barras horizontales proporcionales.
/// - Puntos marcados solo en el máximo y mínimo de cada línea, para comparar.
/// - Toda la paleta migrada a AppColors (adiós verdes/naranjas crudos).
/// - Tope de altura fijo: nunca más se desborda de la pantalla.
class DashboardChartsCard extends StatefulWidget {
  final int financialScore;

  const DashboardChartsCard({super.key, required this.financialScore});

  @override
  State<DashboardChartsCard> createState() => _DashboardChartsCardState();
}

class _DashboardChartsCardState extends State<DashboardChartsCard> {
  final _chartEngine = ChartEngine();
  Map<String, Map<String, double>>? _ingresosGastos;
  Map<String, double>? _categorias;
  List<Map<String, dynamic>>? _metas;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    final ingresosGastos = await _chartEngine.ingresosVsGastosPorMes();
    final categorias = await _chartEngine.gastosPorCategoria();
    final metas = await _chartEngine.progresoMetas();

    setState(() {
      _ingresosGastos = ingresosGastos;
      _categorias = categorias;
      _metas = metas;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    final ingresos = _ingresosGastos?['ingresos'] ?? {};
    final cantidadMeses = ingresos.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Ingresos vs gastos ──
        if (cantidadMeses > 0) ...[
          _buildSubtitulo('Ingresos vs gastos'),
          const SizedBox(height: 12),
          if (cantidadMeses == 1)
            _buildResumenMesUnico(_ingresosGastos!)
          else
            _buildLineaTendencia(_ingresosGastos!),
          const SizedBox(height: 24),
        ],

        // ── Gastos por categoría ──
        if (_categorias != null && _categorias!.isNotEmpty) ...[
          _buildSubtitulo('Gastos por categoría'),
          const SizedBox(height: 12),
          _buildCategorias(_categorias!),
          const SizedBox(height: 24),
        ],

        // ── Progreso de metas ──
        if (_metas != null && _metas!.isNotEmpty) ...[
          _buildSubtitulo('Progreso de metas'),
          const SizedBox(height: 12),
          ..._metas!.map((m) => _buildMetaBar(m)),
        ],

        if (_metas != null && _metas!.isEmpty)
          _buildAvisoVacio(
            'Aún no tienes metas activas. Créalas desde el menú de metas.',
          ),
      ],
    );
  }

  // ── Línea de tendencia (varios meses) ─────────────────────
  Widget _buildLineaTendencia(Map<String, Map<String, double>> data) {
    final claves = (data['ingresos']?.keys.toList() ?? [])..sort();
    if (claves.isEmpty) return const SizedBox();

    // Una sola línea de gastos = fijos + variables.
    final ingresos = <double>[];
    final gastos = <double>[];
    for (final k in claves) {
      ingresos.add(data['ingresos']?[k] ?? 0);
      gastos.add((data['gastosFijos']?[k] ?? 0) +
          (data['gastosVariables']?[k] ?? 0));
    }

    final maxY = [
      ...ingresos,
      ...gastos,
    ].fold(0.0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 140,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY * 1.15,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= claves.length) {
                        return const SizedBox();
                      }
                      final partes = claves[i].split('-');
                      if (partes.length < 2) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          _nombreMes(int.parse(partes[1])),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                _lineaSerie(ingresos, AppColors.primary),
                _lineaSerie(gastos, AppColors.deuda),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _leyendaItem(AppColors.primary, 'Ingresos'),
            const SizedBox(width: 16),
            _leyendaItem(AppColors.deuda, 'Gastos'),
          ],
        ),
      ],
    );
  }

  /// Construye una serie de línea con puntos visibles SOLO en el máximo
  /// y el mínimo — para comparar meses de un vistazo sin ensuciar.
  LineChartBarData _lineaSerie(List<double> valores, Color color) {
    double maxV = valores.first;
    double minV = valores.first;
    int idxMax = 0;
    int idxMin = 0;
    for (int i = 1; i < valores.length; i++) {
      if (valores[i] > maxV) {
        maxV = valores[i];
        idxMax = i;
      }
      if (valores[i] < minV) {
        minV = valores[i];
        idxMin = i;
      }
    }

    return LineChartBarData(
      spots: [
        for (int i = 0; i < valores.length; i++)
          FlSpot(i.toDouble(), valores[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 1.5,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        checkToShowDot: (spot, barData) {
          // Solo el punto más alto y el más bajo.
          return spot.x.toInt() == idxMax || spot.x.toInt() == idxMin;
        },
        getDotPainter: (spot, percent, barData, index) {
          return FlDotCirclePainter(
            radius: 3.5,
            color: color,
            strokeWidth: 0,
            strokeColor: color,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.06),
      ),
    );
  }

  // ── Resumen de mes único (barras proporcionales) ──────────
  Widget _buildResumenMesUnico(Map<String, Map<String, double>> data) {
    final clave = data['ingresos']?.keys.first ?? '';
    final ingreso = data['ingresos']?[clave] ?? 0;
    final fijos = data['gastosFijos']?[clave] ?? 0;
    final variables = data['gastosVariables']?[clave] ?? 0;
    final base = ingreso > 0 ? ingreso : 1;

    return Column(
      children: [
        _barraProporcional('Ingresos', ingreso, 1.0, AppColors.primary),
        const SizedBox(height: 12),
        _barraProporcional(
            'Gastos fijos', fijos, fijos / base, Colors.grey.shade500),
        const SizedBox(height: 12),
        _barraProporcional(
            'Gastos variables', variables, variables / base, AppColors.deuda),
      ],
    );
  }

  Widget _barraProporcional(
      String label, double valor, double fraccion, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(
              _fmtCorto(valor),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: fraccion.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Categorías (barras horizontales, no donut) ────────────
  Widget _buildCategorias(Map<String, double> data) {
    final lista = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = lista.fold(0.0, (s, e) => s + e.value);
    if (total == 0) return const SizedBox();

    // Paleta de marca, en orden de prioridad visual.
    final colores = [
      AppColors.primary,
      AppColors.deuda,
      AppColors.fondo,
      AppColors.acento,
      AppColors.inversion,
      Colors.grey.shade500,
    ];

    return Column(
      children: [
        for (int i = 0; i < lista.length; i++) ...[
          _barraProporcional(
            lista[i].key,
            lista[i].value,
            lista[i].value / total,
            colores[i % colores.length],
          ),
          if (i < lista.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  // ── Barras de metas ───────────────────────────────────────
  Widget _buildMetaBar(Map<String, dynamic> meta) {
    final progreso = (meta['progreso'] as num?)?.toDouble() ?? 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  meta['nombre']?.toString() ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(progreso * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: Colors.grey.withValues(alpha: 0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────
  Widget _buildSubtitulo(String texto) {
    return Text(
      texto,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
  }

  Widget _buildAvisoVacio(String texto) {
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
          Icon(Icons.flag_outlined, color: Colors.grey.shade500, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leyendaItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return mes >= 1 && mes <= 12 ? meses[mes - 1] : '';
  }

  /// Formato corto para montos en las barras (1.2M, 800k, etc.).
  String _fmtCorto(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}
