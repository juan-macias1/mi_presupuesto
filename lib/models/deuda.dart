/// Deuda — registro de una deuda activa o histórica.
///
/// Diferencia clave con Movimiento: aquí se trackea el SALDO REAL
/// pendiente, no las cuotas acumuladas. Cuando el saldo llega a 0,
/// se marca como inactiva pero se conserva para historial.
class Deuda {
  final int? id;
  final String acreedor;
  final String descripcion;
  final double saldoInicial;
  final double saldoActual;
  final double cuotaMensual;
  final double tasaInteres;
  final DateTime fechaInicio;
  final DateTime? fechaEstimadaPago;
  final bool activa;
  final int ordenPago;

  Deuda({
    this.id,
    required this.acreedor,
    this.descripcion = '',
    required this.saldoInicial,
    required this.saldoActual,
    required this.cuotaMensual,
    this.tasaInteres = 0,
    required this.fechaInicio,
    this.fechaEstimadaPago,
    this.activa = true,
    this.ordenPago = 0,
  });

  // ── Derivados ─────────────────────────────────────────────

  /// Porcentaje del saldo inicial que ya fue pagado (0.0 — 1.0).
  /// FIX: `.toDouble()` necesario porque `.clamp(double, double)` retorna
  /// `num` aunque se llame sobre un double — y el getter espera double.
  double get porcentajePagado => saldoInicial > 0
      ? ((saldoInicial - saldoActual) / saldoInicial)
          .clamp(0.0, 1.0)
          .toDouble()
      : 0.0;

  double get montoPagado => saldoInicial - saldoActual;
  bool get estaPagada => saldoActual <= 0;

  /// Meses estimados pagando solo la cuota mínima (sin pagos extra).
  int get mesesEstimadosSoloMinimo =>
      cuotaMensual > 0 ? (saldoActual / cuotaMensual).ceil() : 999;

  // ── Factories ─────────────────────────────────────────────

  factory Deuda.fromMap(Map<String, dynamic> map) {
    return Deuda(
      id: map['id'] as int?,
      acreedor: map['acreedor'] as String,
      descripcion: map['descripcion'] as String? ?? '',
      saldoInicial: (map['saldo_inicial'] as num).toDouble(),
      saldoActual: (map['saldo_actual'] as num).toDouble(),
      cuotaMensual: (map['cuota_mensual'] as num).toDouble(),
      tasaInteres: (map['tasa_interes'] as num?)?.toDouble() ?? 0,
      fechaInicio: DateTime.parse(map['fecha_inicio'] as String),
      fechaEstimadaPago: map['fecha_estimada_pago'] != null
          ? DateTime.parse(map['fecha_estimada_pago'] as String)
          : null,
      activa: map['activa'] == 1,
      ordenPago: map['orden_pago'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'acreedor': acreedor,
      'descripcion': descripcion,
      'saldo_inicial': saldoInicial,
      'saldo_actual': saldoActual,
      'cuota_mensual': cuotaMensual,
      'tasa_interes': tasaInteres,
      'fecha_inicio': fechaInicio.toIso8601String(),
      'fecha_estimada_pago': fechaEstimadaPago?.toIso8601String(),
      'activa': activa ? 1 : 0,
      'orden_pago': ordenPago,
    };
  }

  Map<String, dynamic> toMapConId() => {'id': id, ...toMap()};

  Deuda copyWith({
    int? id,
    String? acreedor,
    String? descripcion,
    double? saldoInicial,
    double? saldoActual,
    double? cuotaMensual,
    double? tasaInteres,
    DateTime? fechaInicio,
    DateTime? fechaEstimadaPago,
    bool? activa,
    int? ordenPago,
  }) {
    return Deuda(
      id: id ?? this.id,
      acreedor: acreedor ?? this.acreedor,
      descripcion: descripcion ?? this.descripcion,
      saldoInicial: saldoInicial ?? this.saldoInicial,
      saldoActual: saldoActual ?? this.saldoActual,
      cuotaMensual: cuotaMensual ?? this.cuotaMensual,
      tasaInteres: tasaInteres ?? this.tasaInteres,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaEstimadaPago: fechaEstimadaPago ?? this.fechaEstimadaPago,
      activa: activa ?? this.activa,
      ordenPago: ordenPago ?? this.ordenPago,
    );
  }

  @override
  String toString() => 'Deuda(acreedor: $acreedor, '
      'saldo: $saldoActual / $saldoInicial, '
      'pagado: ${(porcentajePagado * 100).toStringAsFixed(1)}%)';
}