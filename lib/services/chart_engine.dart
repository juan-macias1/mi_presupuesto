import '../db/database_helper.dart';
import '../models/movimiento.dart';
import '../models/meta_ahorro.dart';

class ChartEngine {
  final db = DatabaseHelper.instance;

  // ── Ingresos vs Gastos por mes ────────────────────────────
  Future<Map<String, Map<String, double>>> ingresosVsGastosPorMes() async {
    final movimientosMap = await db.obtenerMovimientos();
    final movimientos = movimientosMap
        .map((m) => Movimiento.fromMap(m))
        .toList();

    // FIX #6: guard de datos vacíos
    if (movimientos.isEmpty) {
      return {"ingresos": {}, "gastosFijos": {}, "gastosVariables": {}};
    }

    Map<String, double> ingresosPorMes = {};
    Map<String, double> gastosFijosPorMes = {};
    Map<String, double> gastosVariablesPorMes = {};

    for (var m in movimientos) {
      final clave =
          "${m.fecha.year}-${m.fecha.month.toString().padLeft(2, '0')}";

      if (m.tipo == "ingreso") {
        ingresosPorMes[clave] = (ingresosPorMes[clave] ?? 0) + m.valor;
      } else if (m.tipo == "gasto") {
        // FIX #1: deudas excluidas de la gráfica de gastos operativos
        if (m.esDeuda) continue;

        // FIX #5: separar fijos de variables para gráfica más informativa
        if (m.esFijo) {
          gastosFijosPorMes[clave] =
              (gastosFijosPorMes[clave] ?? 0) + m.valor;
        } else {
          gastosVariablesPorMes[clave] =
              (gastosVariablesPorMes[clave] ?? 0) + m.valor;
        }
      }
    }

    // Últimos 6 meses con datos
    final todasClaves = {
      ...ingresosPorMes.keys,
      ...gastosFijosPorMes.keys,
      ...gastosVariablesPorMes.keys,
    }.toList()..sort();

    final ultimas6 = todasClaves.length > 6
        ? todasClaves.sublist(todasClaves.length - 6)
        : todasClaves;

    Map<String, double> ingresosFiltrados = {};
    Map<String, double> fijosFiltrados = {};
    Map<String, double> variablesFiltrados = {};

    for (var clave in ultimas6) {
      ingresosFiltrados[clave] = ingresosPorMes[clave] ?? 0;
      fijosFiltrados[clave] = gastosFijosPorMes[clave] ?? 0;
      variablesFiltrados[clave] = gastosVariablesPorMes[clave] ?? 0;
    }

    return {
      "ingresos": ingresosFiltrados,
      "gastosFijos": fijosFiltrados,
      "gastosVariables": variablesFiltrados,
    };
  }

  // ── Gastos por categoría ──────────────────────────────────
  Future<Map<String, double>> gastosPorCategoria() async {
    final movimientosMap = await db.obtenerMovimientos();
    final movimientos = movimientosMap
        .map((m) => Movimiento.fromMap(m))
        .toList();

    // FIX #6: guard de datos vacíos
    if (movimientos.isEmpty) return {};

    Map<String, double> gastos = {};

    for (var m in movimientos) {
      // FIX #2 y #3: deudas excluidas del pie chart de categorías
      if (m.tipo == "gasto" && !m.esDeuda) {
        gastos[m.categoria] = (gastos[m.categoria] ?? 0) + m.valor;
      }
    }

    if (gastos.isEmpty) return {};

    // Ordenar por mayor gasto
    final lista = gastos.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Top 6 categorías + "Otros" para el resto
    if (lista.length > 6) {
      double otros = lista.sublist(6).fold(0, (s, e) => s + e.value);
      Map<String, double> resultado = {};
      for (var e in lista.take(6)) {
        resultado[e.key] = e.value;
      }
      if (otros > 0) resultado['Otros'] = otros;
      return resultado;
    }

    return Map.fromEntries(lista);
  }

  // ── Deudas por acreedor ───────────────────────────────────
  // Gráfica separada exclusiva para deudas — no se mezcla con gastos operativos
  Future<Map<String, double>> deudasPorAcreedor() async {
    final movimientosMap = await db.obtenerMovimientos();
    final movimientos = movimientosMap
        .map((m) => Movimiento.fromMap(m))
        .toList();

    if (movimientos.isEmpty) return {};

    Map<String, double> deudas = {};

    for (var m in movimientos) {
      if (m.tipo == "gasto" && m.esDeuda) {
        final acreedor =
            (m.acreedor != null && m.acreedor!.trim().isNotEmpty)
                ? m.acreedor!.trim()
                : 'Sin acreedor';
        deudas[acreedor] = (deudas[acreedor] ?? 0) + m.valor;
      }
    }

    // Ordenar por mayor deuda
    final lista = deudas.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Map.fromEntries(lista);
  }

  // ── Progreso de metas ─────────────────────────────────────
  Future<List<Map<String, dynamic>>> progresoMetas() async {
    final metasData = await db.obtenerMetas();

    // FIX #6: guard de datos vacíos
    if (metasData.isEmpty) return [];

    final metas = metasData.map((e) => MetaAhorro.fromMap(e)).toList();

    return metas
        .where((m) => m.activa)
        .map((m) {
          // FIX #4: guard contra división por cero en montoObjetivo
          final progreso = m.montoObjetivo > 0
              ? (m.montoAhorrado / m.montoObjetivo).clamp(0.0, 1.0)
              : 0.0;

          return {
            "nombre": m.nombre,
            "progreso": progreso,
            "montoAhorrado": m.montoAhorrado,
            "montoObjetivo": m.montoObjetivo,
          };
        })
        .toList();
  }
}
