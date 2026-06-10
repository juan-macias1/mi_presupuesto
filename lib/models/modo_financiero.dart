import 'flujo_mensual.dart';

/// ModoFinanciero — el estado actual de las finanzas de Juan.
/// Todo el comportamiento de la app cambia según este modo.
enum ModoFinanciero {
  /// Sin movimientos registrados este mes
  sinDatos,

  /// Ingresos no alcanzan para cubrir gastos fijos + cuotas de deuda
  supervivencia,

  /// Hay deudas activas y excedente para atacarlas
  ataque,

  /// Sin deudas — modo construcción de patrimonio
  libertad;

  // ── Factories ─────────────────────────────────────────────

  /// Determina el modo automáticamente a partir del flujo mensual
  static ModoFinanciero desde(FlujoMensual flujo) {
    if (flujo.ingresos == 0 && flujo.gastosOperativos == 0) {
      return ModoFinanciero.sinDatos;
    }
    if (flujo.enSupervivencia) {
      return ModoFinanciero.supervivencia;
    }
    if (flujo.totalDeudaReal > 0) {
      return ModoFinanciero.ataque;
    }
    return ModoFinanciero.libertad;
  }

  static ModoFinanciero fromString(String valor) {
    switch (valor) {
      case 'supervivencia':
        return ModoFinanciero.supervivencia;
      case 'ataque':
        return ModoFinanciero.ataque;
      case 'libertad':
        return ModoFinanciero.libertad;
      default:
        return ModoFinanciero.sinDatos;
    }
  }

  // ── Propiedades de presentación ───────────────────────────

  String get label {
    switch (this) {
      case ModoFinanciero.sinDatos:
        return 'Sin datos';
      case ModoFinanciero.supervivencia:
        return 'Supervivencia';
      case ModoFinanciero.ataque:
        return 'Modo ataque';
      case ModoFinanciero.libertad:
        return 'Libertad financiera';
    }
  }

  String get emoji {
    switch (this) {
      case ModoFinanciero.sinDatos:
        return '📋';
      case ModoFinanciero.supervivencia:
        return '🆘';
      case ModoFinanciero.ataque:
        return '⚔️';
      case ModoFinanciero.libertad:
        return '🚀';
    }
  }

  String get descripcion {
    switch (this) {
      case ModoFinanciero.sinDatos:
        return 'Registra tus movimientos para comenzar el análisis.';
      case ModoFinanciero.supervivencia:
        return 'Tus ingresos no alcanzan para cubrir lo básico. Prioridad: reducir gastos fijos.';
      case ModoFinanciero.ataque:
        return 'Tienes deudas activas. Cada peso extra que liberes va directo a eliminarlas.';
      case ModoFinanciero.libertad:
        return 'Sin deudas. Es momento de construir tu patrimonio.';
    }
  }

  String get accionPrincipal {
    switch (this) {
      case ModoFinanciero.sinDatos:
        return 'Registrar primer movimiento';
      case ModoFinanciero.supervivencia:
        return 'Reducir gastos fijos';
      case ModoFinanciero.ataque:
        return 'Ver plan de deudas';
      case ModoFinanciero.libertad:
        return 'Ver plan de inversión';
    }
  }

  bool get tieneDeudas => this == ModoFinanciero.ataque;
  bool get esCritico => this == ModoFinanciero.supervivencia;
  bool get estaLibre => this == ModoFinanciero.libertad;
  bool get sinInformacion => this == ModoFinanciero.sinDatos;
}
