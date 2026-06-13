import 'package:flutter/material.dart';

/// DashboardScoreCard — muestra el score financiero (0-100) con color semántico.
///
/// Diseño base: número grande, label según rango, mensaje corto.
/// El estilo visual está pensado para iterarse en la fase de UX,
/// pero el contrato del widget queda fijo: recibe `score` y opcionalmente
/// `mensaje` si quiere sobreescribirse el default.
class DashboardScoreCard extends StatelessWidget {
  final int score;
  final String? mensaje;

  const DashboardScoreCard({
    super.key,
    required this.score,
    this.mensaje,
  });

  // ── Mapeo de score a estado visual ────────────────────────

  _ScoreVisual get _visual {
    if (score >= 80) {
      return const _ScoreVisual(
        label: 'Excelente',
        color: Color(0xFF2E7D32), // verde profundo
        backgroundColor: Color(0xFFE8F5E9),
        icon: Icons.sentiment_very_satisfied,
        mensajeDefault: 'Tu salud financiera está sólida. Mantén el ritmo.',
      );
    } else if (score >= 60) {
      return const _ScoreVisual(
        label: 'Bueno',
        color: Color(0xFF558B2F), // verde claro
        backgroundColor: Color(0xFFF1F8E9),
        icon: Icons.sentiment_satisfied,
        mensajeDefault: 'Vas por buen camino. Hay margen para mejorar.',
      );
    } else if (score >= 40) {
      return const _ScoreVisual(
        label: 'Regular',
        color: Color(0xFFEF6C00), // naranja
        backgroundColor: Color(0xFFFFF3E0),
        icon: Icons.sentiment_neutral,
        mensajeDefault: 'Cuidado con los gastos. Revisá tus hábitos.',
      );
    } else {
      return const _ScoreVisual(
        label: 'En riesgo',
        color: Color(0xFFC62828), // rojo
        backgroundColor: Color(0xFFFFEBEE),
        icon: Icons.sentiment_very_dissatisfied,
        mensajeDefault: 'Tu situación financiera requiere atención urgente.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    final textoMensaje = mensaje ?? visual.mensajeDefault;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: visual.backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(visual.icon, color: visual.color, size: 32),
                const SizedBox(width: 12),
                Text(
                  'Score Financiero',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: visual.color.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: visual.color,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    '/ 100',
                    style: TextStyle(
                      fontSize: 18,
                      color: visual.color.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: visual.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    visual.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              textoMensaje,
              style: TextStyle(
                fontSize: 13,
                color: visual.color.withValues(alpha: 0.85),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper interno: agrupa los atributos visuales para cada rango de score.
class _ScoreVisual {
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
  final String mensajeDefault;

  const _ScoreVisual({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
    required this.mensajeDefault,
  });
}
