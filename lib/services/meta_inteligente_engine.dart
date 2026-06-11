import 'dart:math';
import '../models/meta_ahorro.dart';
import '../models/meta_inteligente.dart';
import '../models/master_financial_result.dart';

/// MetaInteligenteEngine — calcula proyecciones y aportes ponderados por meta.
///
/// Esta versión consume `MasterFinancialResult` (single source of truth)
/// en lugar de instanciar `FinancialEngine` y `DistributionEngine` propios.
/// El llamador es responsable de obtener el result del brain antes.
class MetaInteligenteEngine {
  Future<List<MetaInteligente>> analizarMetas(
    List<MetaAhorro> metas,
    MasterFinancialResult result,
  ) async {
    if (metas.isEmpty) return [];

    final analysis = result.analysis;
    final distribucion = result.distribucion;

    if (analysis.ingresos == 0 && analysis.gastos == 0) return [];

    final double excedenteReal = distribucion.excedenteReal;
    final double disponibleParaMetas = distribucion.montoMetas;

    final metasActivas = metas.where((m) => m.activa).toList();
    if (metasActivas.isEmpty) return [];

    metasActivas.sort((a, b) => a.fechaObjetivo.compareTo(b.fechaObjetivo));

    final aportePorMeta = _calcularAportesPonderados(
      metasActivas,
      disponibleParaMetas,
    );

    List<MetaInteligente> metasInteligentes = [];

    for (var meta in metas) {
      if (!meta.activa) continue;

      final double restante = meta.montoObjetivo - meta.montoAhorrado;
      final DateTime ahora = DateTime.now();
      final int diasRestantes = meta.fechaObjetivo.difference(ahora).inDays;

      if (restante <= 0) {
        metasInteligentes.add(MetaInteligente(
          metaId: meta.id,
          nombre: meta.nombre,
          estado: "CUMPLIDA",
          descripcionEstado: "¡Meta alcanzada!",
          mesesProyectados: 0,
          fechaProyectada: ahora,
          llegaraATiempo: true,
          aporteMensualSugerido: 0,
          aporteMensualParaLlegar: 0,
          porcentajeDelExcedente: 0,
          esViable: true,
          mensaje: "🎉 ¡Felicitaciones! Lograste esta meta.",
        ));
        continue;
      }

      if (diasRestantes < 0) {
        metasInteligentes.add(MetaInteligente(
          metaId: meta.id,
          nombre: meta.nombre,
          estado: "VENCIDA",
          descripcionEstado: "La fecha objetivo ya pasó.",
          mesesProyectados: 0,
          fechaProyectada: meta.fechaObjetivo,
          llegaraATiempo: false,
          aporteMensualSugerido: aportePorMeta[meta.id] ?? 0,
          aporteMensualParaLlegar: restante,
          porcentajeDelExcedente: 0,
          esViable: false,
          mensaje: "La fecha de esta meta ya venció. Puedes actualizarla para seguir ahorrando hacia ella.",
        ));
        continue;
      }

      final double aporteAsignado = aportePorMeta[meta.id] ?? 0;
      final double mesesRestantes = max(diasRestantes / 30.0, 1.0);
      final double aporteMensualParaLlegar = restante / mesesRestantes;

      int mesesProyectados;
      DateTime fechaProyectada;

      if (aporteAsignado <= 0) {
        mesesProyectados = -1;
        fechaProyectada = DateTime(9999);
      } else {
        mesesProyectados = (restante / aporteAsignado).ceil();
        fechaProyectada = ahora.add(Duration(days: mesesProyectados * 30));
      }

      final bool llegaraATiempo = mesesProyectados > 0 &&
          mesesProyectados != -1 &&
          !fechaProyectada.isAfter(meta.fechaObjetivo);

      final double porcentajeDelExcedente = excedenteReal == 0
          ? 0
          : (aporteAsignado / excedenteReal) * 100;

      final bool esViable = aporteMensualParaLlegar <= disponibleParaMetas;

      String estado;
      String descripcionEstado;

      if (aporteAsignado <= 0) {
        estado = "EN_RIESGO";
        descripcionEstado = "No hay excedente disponible para aportar a esta meta.";
      } else if (llegaraATiempo && aporteAsignado >= aporteMensualParaLlegar) {
        estado = "ACELERADA";
        descripcionEstado = "Vas por encima del ritmo necesario.";
      } else if (llegaraATiempo) {
        estado = "EN_CAMINO";
        descripcionEstado = "Vas bien, llegarías a tiempo.";
      } else {
        estado = "EN_RIESGO";
        descripcionEstado = "Con el ritmo actual no llegarías a tiempo.";
      }

      String mensaje;
      if (estado == "ACELERADA") {
        mensaje = "Vas excelente 💪 Con \$${aporteAsignado.toStringAsFixed(0)} al mes "
            "llegarías a esta meta en $mesesProyectados meses, antes de tu fecha objetivo.";
      } else if (estado == "EN_CAMINO") {
        mensaje = "Necesitas \$${aporteMensualParaLlegar.toStringAsFixed(0)} al mes "
            "para llegar a tiempo. Tu aporte sugerido es \$${aporteAsignado.toStringAsFixed(0)}.";
      } else {
        if (aporteAsignado <= 0) {
          mensaje = "No hay excedente disponible para esta meta ahora mismo. Reducir gastos es el primer paso.";
        } else {
          mensaje = "Necesitas \$${aporteMensualParaLlegar.toStringAsFixed(0)} al mes "
              "pero solo tienes \$${aporteAsignado.toStringAsFixed(0)} disponible. "
              "Considera extender la fecha objetivo o reducir gastos variables.";
        }
      }

      metasInteligentes.add(MetaInteligente(
        metaId: meta.id,
        nombre: meta.nombre,
        estado: estado,
        descripcionEstado: descripcionEstado,
        mesesProyectados: mesesProyectados == -1 ? 0 : mesesProyectados,
        fechaProyectada: mesesProyectados == -1 ? meta.fechaObjetivo : fechaProyectada,
        llegaraATiempo: llegaraATiempo,
        aporteMensualSugerido: aporteAsignado,
        aporteMensualParaLlegar: aporteMensualParaLlegar,
        porcentajeDelExcedente: porcentajeDelExcedente,
        esViable: esViable,
        mensaje: mensaje,
      ));
    }

    return metasInteligentes;
  }

  /// Pondera los aportes por urgencia (1/dias_restantes) y reparte el monto disponible.
  Map<dynamic, double> _calcularAportesPonderados(
    List<MetaAhorro> metasActivas,
    double disponible,
  ) {
    if (disponible <= 0 || metasActivas.isEmpty) {
      return {for (var m in metasActivas) m.id: 0.0};
    }

    final DateTime ahora = DateTime.now();
    Map<dynamic, double> pesos = {};
    double totalPesos = 0;

    for (var meta in metasActivas) {
      final int diasRestantes =
          max(meta.fechaObjetivo.difference(ahora).inDays, 1);
      final double restante = meta.montoObjetivo - meta.montoAhorrado;

      if (restante <= 0) {
        pesos[meta.id] = 0;
        continue;
      }

      final double peso = 1.0 / diasRestantes;
      pesos[meta.id] = peso;
      totalPesos += peso;
    }

    Map<dynamic, double> aportes = {};
    for (var meta in metasActivas) {
      if (totalPesos == 0) {
        aportes[meta.id] = disponible / metasActivas.length;
      } else {
        aportes[meta.id] = disponible * ((pesos[meta.id] ?? 0) / totalPesos);
      }
    }

    return aportes;
  }
}
