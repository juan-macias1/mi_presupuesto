import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/chart_engine.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Gráfica 1: Ingresos vs Gastos ───────────────────
        // BUG FIX #1: usar clave 'ingresos' correcta del ChartEngine corregido
        if (_ingresosGastos != null &&
            (_ingresosGastos!['ingresos']?.isNotEmpty ?? false)) ...[
          _buildSubtitulo('📊 Ingresos vs Gastos por mes'),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildBarChart(_ingresosGastos!)),
          const SizedBox(height: 8),
          // BUG FIX #2: leyenda actualizada con 3 series
          _buildLeyenda(),
          const SizedBox(height: 24),
        ],

        // ── Gráfica 2: Gastos por categoría ─────────────────
        if (_categorias != null && _categorias!.isNotEmpty) ...[
          _buildSubtitulo('🥧 Gastos por categoría'),
          const SizedBox(height: 12),
          SizedBox(height: 200, child: _buildPieChart(_categorias!)),
          const SizedBox(height: 12),
          _buildLeyendaCategorias(_categorias!),
          const SizedBox(height: 24),
        ],

        // ── Gráfica 3: Score financiero ──────────────────────
        _buildSubtitulo('📈 Score financiero actual'),
        const SizedBox(height: 12),
        SizedBox(height: 120, child: _buildScoreChart()),
        const SizedBox(height: 24),

        // ── Gráfica 4: Progreso de metas ─────────────────────
        if (_metas != null && _metas!.isNotEmpty) ...[
          _buildSubtitulo('🎯 Progreso de metas'),
          const SizedBox(height: 12),
          ..._metas!.map((m) => _buildMetaBar(m)),
        ],

        // Sin metas — mensaje amigable sin overflow
        if (_metas != null && _metas!.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.flag_outlined, color: Colors.grey, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aún no tienes metas activas. Crea una desde el menú de metas.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Bar Chart: Ingresos vs Gastos Fijos vs Variables ──────
  // BUG FIX #1: usa las claves correctas 'ingresos', 'gastosFijos', 'gastosVariables'
  Widget _buildBarChart(Map<String, Map<String, double>> data) {
    final claves = data['ingresos']?.keys.toList() ?? [];

    if (claves.isEmpty) return const SizedBox();

    List<BarChartGroupData> grupos = [];

    for (int i = 0; i < claves.length; i++) {
      final clave = claves[i];
      final ingreso = data['ingresos']?[clave] ?? 0;
      final gastoFijo = data['gastosFijos']?[clave] ?? 0;
      final gastoVariable = data['gastosVariables']?[clave] ?? 0;

      grupos.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: ingreso,
              color: Colors.green,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: gastoFijo,
              color: Colors.redAccent,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            BarChartRodData(
              toY: gastoVariable,
              color: Colors.orange,
              width: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: grupos,
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
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= claves.length) return const SizedBox();
                final partes = claves[index].split('-');
                if (partes.length < 2) return const SizedBox();
                final mes = _nombreMes(int.parse(partes[1]));
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(mes, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ── Pie Chart: Gastos por categoría ──────────────────────
  Widget _buildPieChart(Map<String, double> data) {
    final colores = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.grey,
    ];

    final lista = data.entries.toList();
    final total = lista.fold(0.0, (s, e) => s + e.value);

    if (total == 0) return const SizedBox();

    List<PieChartSectionData> secciones = [];

    for (int i = 0; i < lista.length; i++) {
      final porcentaje = lista[i].value / total * 100;
      secciones.add(
        PieChartSectionData(
          value: lista[i].value,
          color: colores[i % colores.length],
          title: '${porcentaje.toStringAsFixed(0)}%',
          radius: 80,
          titleStyle: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return PieChart(PieChartData(sections: secciones));
  }

  // ── Score financiero ──────────────────────────────────────
  Widget _buildScoreChart() {
    final score = widget.financialScore.toDouble();

    // score <= 0 cubre dos casos: 0 (sin movimientos) y -1 (datos
    // insuficientes para calcular). En ambos no mostramos un número.
    if (score <= 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey, size: 16),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Registra tus gastos del mes para calcular tu score.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    final color = score >= 70
        ? Colors.green
        : score >= 40
        ? Colors.orange
        : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${widget.financialScore}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const Text(
              ' / 100',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 16,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score >= 70
              ? 'Excelente salud financiera'
              : score >= 40
              ? 'Salud financiera en desarrollo'
              : 'Salud financiera en riesgo',
          style: TextStyle(fontSize: 12, color: color),
        ),
      ],
    );
  }

  // ── Barras horizontales: Progreso metas ──────────────────
  Widget _buildMetaBar(Map<String, dynamic> meta) {
    final progreso = (meta['progreso'] as num?)?.toDouble() ?? 0.0;
    final color = progreso < 0.4
        ? Colors.red
        : progreso < 0.8
        ? Colors.orange
        : Colors.green;

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
              SizedBox(
                width: 40,
                child: Text(
                  '${(progreso * 100).toStringAsFixed(0)}%',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progreso.clamp(0.0, 1.0).toDouble(),
              minHeight: 10,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  // BUG FIX #2: leyenda actualizada con las 3 series correctas
  Widget _buildLeyenda() {
    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        _buildLeyendaItem(Colors.green, 'Ingresos'),
        _buildLeyendaItem(Colors.redAccent, 'Gastos fijos'),
        _buildLeyendaItem(Colors.orange, 'Gastos variables'),
      ],
    );
  }

  Widget _buildLeyendaItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildLeyendaCategorias(Map<String, double> data) {
    final colores = [
      Colors.blue,
      Colors.orange,
      Colors.green,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.grey,
    ];

    final lista = data.entries.toList();

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: List.generate(lista.length, (i) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: colores[i % colores.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
            Text(lista[i].key, style: const TextStyle(fontSize: 11)),
          ],
        );
      }),
    );
  }

  String _nombreMes(int mes) {
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return mes >= 1 && mes <= 12 ? meses[mes - 1] : '';
  }
}
