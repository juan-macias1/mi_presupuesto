import 'package:flutter/material.dart';
import '../models/financial_risk.dart';

/// DashboardRiskChip — renderiza un FinancialRisk como un chip de Material.
///
/// Usa el getter tipado `risk.nivelTipado` (enum NivelRiesgo) en lugar
/// del string crudo. Eso elimina la posibilidad de typos silenciosos
/// en la UI: si el modelo retorna un nivel desconocido, cae al default.
class DashboardRiskChip extends StatelessWidget {
  final FinancialRisk risk;
  final VoidCallback? onTap;

  const DashboardRiskChip({
    super.key,
    required this.risk,
    this.onTap,
  });

  // ── Mapeo de nivel a estado visual ────────────────────────

  _RiskVisual get _visual {
    switch (risk.nivelTipado) {
      case NivelRiesgo.critico:
        return const _RiskVisual(
          color: Color(0xFFC62828),
          backgroundColor: Color(0xFFFFEBEE),
          icon: Icons.error,
        );
      case NivelRiesgo.alto:
        return const _RiskVisual(
          color: Color(0xFFEF6C00),
          backgroundColor: Color(0xFFFFF3E0),
          icon: Icons.warning,
        );
      case NivelRiesgo.medio:
        return const _RiskVisual(
          color: Color(0xFFF9A825),
          backgroundColor: Color(0xFFFFFDE7),
          icon: Icons.warning_amber,
        );
      case NivelRiesgo.bajo:
        return const _RiskVisual(
          color: Color(0xFF558B2F),
          backgroundColor: Color(0xFFF1F8E9),
          icon: Icons.info_outline,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: visual.backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: visual.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(visual.icon, color: visual.color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              risk.titulo,
              style: TextStyle(
                color: visual.color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: chip,
    );
  }
}

/// Helper interno: agrupa los atributos visuales para cada nivel de riesgo.
class _RiskVisual {
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  const _RiskVisual({
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });
}
