import 'dart:math';
import 'package:flutter/material.dart';
import '../models/meta_ahorro.dart';
import '../models/meta_inteligente.dart';
import 'package:intl/intl.dart';

class MetaCard extends StatelessWidget {
  final MetaAhorro meta;
  final MetaInteligente? metaInteligente;

  const MetaCard({super.key, required this.meta, this.metaInteligente});

  // FIX #4: NumberFormat estático — no se recrea en cada build
  static final _formato = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // FIX #3: calcularPlanAhorro usa aporteMensualSugerido del motor si está disponible
  // Solo calcula por su cuenta como fallback cuando no hay metaInteligente
  Map<String, double> calcularPlanAhorro() {
    // Si el motor ya calculó el aporte óptimo, usarlo directamente
    if (metaInteligente != null &&
        metaInteligente!.aporteMensualSugerido > 0) {
      final mensual = metaInteligente!.aporteMensualSugerido;
      final semanal = mensual / 4.33;
      return {"mensual": mensual, "semanal": semanal};
    }

    // Fallback: cálculo simple cuando no hay motor disponible
    final restante = meta.montoObjetivo - meta.montoAhorrado;
    final diasRestantes = meta.fechaObjetivo.difference(DateTime.now()).inDays;

    // FIX #7: piso mínimo de 1 mes para evitar valores absurdos
    final mesesRestantes = max(diasRestantes / 30.0, 1.0);
    final semanasRestantes = max(diasRestantes / 7.0, 1.0);

    final ahorroMensual = restante / mesesRestantes;
    final ahorroSemanal = restante / semanasRestantes;

    return {"mensual": ahorroMensual, "semanal": ahorroSemanal};
  }

  // FIX #6: mensajeProgreso ahora considera metas vencidas
  String mensajeProgreso(double progreso) {
    final diasRestantes =
        meta.fechaObjetivo.difference(DateTime.now()).inDays;

    if (progreso >= 1) {
      return "Meta cumplida 🎉";
    } else if (diasRestantes < 0) {
      return "Fecha vencida ⚠️";
    } else if (progreso < 0.3) {
      return "Vas empezando";
    } else if (progreso < 0.7) {
      return "Buen progreso";
    } else {
      return "¡Casi lo logras!";
    }
  }

  // FIX #8: método estático privado dentro de la clase, no función global
  static Color _colorProgreso(double progreso) {
    if (progreso >= 1) {
      return Colors.green;
    } else if (progreso >= 0.8) {
      return Colors.green;
    } else if (progreso >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    // FIX #1: guard contra división por cero en montoObjetivo
    final double progreso = meta.montoObjetivo > 0
        ? (meta.montoAhorrado / meta.montoObjetivo).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final porcentaje = (progreso * 100).toStringAsFixed(1);
    final colorProgreso = _colorProgreso(progreso);
    final mensaje = mensajeProgreso(progreso);
    final plan = calcularPlanAhorro();
    final fecha = DateFormat('d MMM y', 'es_CO').format(meta.fechaObjetivo);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meta.nombre,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Meta para $fecha",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            Text(
              "${_formato.format(meta.montoAhorrado)} / ${_formato.format(meta.montoObjetivo)}",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              "$porcentaje %",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progreso,
              minHeight: 10,
              color: colorProgreso,
              backgroundColor: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: colorProgreso,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "Ahorro mensual sugerido: ${_formato.format(plan["mensual"])}",
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              "Ahorro semanal sugerido: ${_formato.format(plan["semanal"])}",
              style: const TextStyle(fontSize: 12),
            ),

            // ── Análisis inteligente ──────────────────────────
            if (metaInteligente != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              _buildAnalisisInteligente(context, metaInteligente!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalisisInteligente(
    BuildContext context,
    MetaInteligente mi,
  ) {
    Color colorEstado;
    IconData iconoEstado;

    // FIX #2: estado "VENCIDA" agregado al switch
    // FIX #10: todos los cases con llaves
    switch (mi.estado) {
      case 'ACELERADA':
        {
          colorEstado = Colors.green;
          iconoEstado = Icons.rocket_launch_outlined;
          break;
        }
      case 'EN_CAMINO':
        {
          colorEstado = Colors.blue;
          iconoEstado = Icons.trending_up;
          break;
        }
      case 'EN_RIESGO':
        {
          colorEstado = Colors.orange;
          iconoEstado = Icons.warning_amber_outlined;
          break;
        }
      case 'CUMPLIDA':
        {
          colorEstado = Colors.green;
          iconoEstado = Icons.check_circle_outline;
          break;
        }
      case 'VENCIDA':
        {
          colorEstado = Colors.red;
          iconoEstado = Icons.event_busy_outlined;
          break;
        }
      default:
        {
          colorEstado = Colors.grey;
          iconoEstado = Icons.info_outline;
        }
    }

    // FIX #5: guard para fecha centinela DateTime(9999)
    final bool fechaValida = mi.fechaProyectada.year < 9000;
    final String fechaProyectadaTexto = fechaValida
        ? DateFormat('MMM y', 'es_CO').format(mi.fechaProyectada)
        : 'Indefinido';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(iconoEstado, color: colorEstado, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                mi.descripcionEstado,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorEstado,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // FIX #9: withValues(alpha:) en vez de withOpacity()
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorEstado.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colorEstado.withValues(alpha: 0.2)),
          ),
          child: Text(
            mi.mensaje,
            style: const TextStyle(fontSize: 12, height: 1.4),
          ),
        ),

        if (mi.estado != 'CUMPLIDA' && mi.estado != 'VENCIDA') ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Aporte sugerido:',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                _formato.format(mi.aporteMensualSugerido),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Fecha proyectada:',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                fechaProyectadaTexto,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: mi.llegaraATiempo ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Necesitas al mes:',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                _formato.format(mi.aporteMensualParaLlegar),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: mi.esViable ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        ],

        // Estado VENCIDA: mostrar cuánto falta para replantear la meta
        if (mi.estado == 'VENCIDA') ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Faltó ahorrar:',
                style: TextStyle(fontSize: 12),
              ),
              Text(
                _formato.format(mi.aporteMensualParaLlegar),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
