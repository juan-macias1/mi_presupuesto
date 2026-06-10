class FinancialTrend {
  final double cambioGastos;
  final double cambioIngresos;
  final double cambioDeuda;
  final String mensaje;

  FinancialTrend({
    required this.cambioGastos,
    required this.cambioIngresos,
    required this.cambioDeuda,
    required this.mensaje,
  });

  // FIX #4: factory para estado vacío/inicial
  factory FinancialTrend.empty() {
    return FinancialTrend(
      cambioGastos: 0,
      cambioIngresos: 0,
      cambioDeuda: 0,
      mensaje: 'Aún no hay suficientes datos para analizar tendencias.',
    );
  }

  // FIX #1: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'cambio_gastos': cambioGastos,
      'cambio_ingresos': cambioIngresos,
      'cambio_deuda': cambioDeuda,
      'mensaje': mensaje,
    };
  }

  factory FinancialTrend.fromMap(Map<String, dynamic> map) {
    return FinancialTrend(
      cambioGastos: (map['cambio_gastos'] as num).toDouble(),
      cambioIngresos: (map['cambio_ingresos'] as num).toDouble(),
      cambioDeuda: (map['cambio_deuda'] as num).toDouble(),
      mensaje: map['mensaje'] as String,
    );
  }

  // FIX #2: copyWith
  FinancialTrend copyWith({
    double? cambioGastos,
    double? cambioIngresos,
    double? cambioDeuda,
    String? mensaje,
  }) {
    return FinancialTrend(
      cambioGastos: cambioGastos ?? this.cambioGastos,
      cambioIngresos: cambioIngresos ?? this.cambioIngresos,
      cambioDeuda: cambioDeuda ?? this.cambioDeuda,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  // FIX #3: toString
  @override
  String toString() {
    return 'FinancialTrend(\n'
        '  cambioGastos: ${cambioGastos.toStringAsFixed(1)}%\n'
        '  cambioIngresos: ${cambioIngresos.toStringAsFixed(1)}%\n'
        '  cambioDeuda: ${cambioDeuda.toStringAsFixed(1)}%\n'
        ')';
  }
}
