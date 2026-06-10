class FinancialProjection {
  final double ingresoPromedio;
  final double gastoPromedio;
  final double ahorroMensual;
  final double ahorro12Meses;
  final String mensaje;
  final int mesesParaSalirDeDeuda;
  final int mesesParaFondoCompleto;

  FinancialProjection({
    required this.ingresoPromedio,
    required this.gastoPromedio,
    required this.ahorroMensual,
    required this.ahorro12Meses,
    required this.mensaje,
    required this.mesesParaSalirDeDeuda,
    required this.mesesParaFondoCompleto,
  });

  // FIX #4: factory para estado vacío/inicial
  factory FinancialProjection.empty() {
    return FinancialProjection(
      ingresoPromedio: 0,
      gastoPromedio: 0,
      ahorroMensual: 0,
      ahorro12Meses: 0,
      mensaje: 'Registra movimientos para ver tu proyección financiera.',
      mesesParaSalirDeDeuda: 0,
      mesesParaFondoCompleto: 0,
    );
  }

  // FIX #1: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'ingreso_promedio': ingresoPromedio,
      'gasto_promedio': gastoPromedio,
      'ahorro_mensual': ahorroMensual,
      'ahorro_12_meses': ahorro12Meses,
      'mensaje': mensaje,
      'meses_para_salir_deuda': mesesParaSalirDeDeuda,
      'meses_para_fondo_completo': mesesParaFondoCompleto,
    };
  }

  factory FinancialProjection.fromMap(Map<String, dynamic> map) {
    return FinancialProjection(
      ingresoPromedio: (map['ingreso_promedio'] as num).toDouble(),
      gastoPromedio: (map['gasto_promedio'] as num).toDouble(),
      ahorroMensual: (map['ahorro_mensual'] as num).toDouble(),
      ahorro12Meses: (map['ahorro_12_meses'] as num).toDouble(),
      mensaje: map['mensaje'] as String,
      mesesParaSalirDeDeuda: map['meses_para_salir_deuda'] as int,
      mesesParaFondoCompleto: map['meses_para_fondo_completo'] as int,
    );
  }

  // FIX #2: copyWith
  FinancialProjection copyWith({
    double? ingresoPromedio,
    double? gastoPromedio,
    double? ahorroMensual,
    double? ahorro12Meses,
    String? mensaje,
    int? mesesParaSalirDeDeuda,
    int? mesesParaFondoCompleto,
  }) {
    return FinancialProjection(
      ingresoPromedio: ingresoPromedio ?? this.ingresoPromedio,
      gastoPromedio: gastoPromedio ?? this.gastoPromedio,
      ahorroMensual: ahorroMensual ?? this.ahorroMensual,
      ahorro12Meses: ahorro12Meses ?? this.ahorro12Meses,
      mensaje: mensaje ?? this.mensaje,
      mesesParaSalirDeDeuda:
          mesesParaSalirDeDeuda ?? this.mesesParaSalirDeDeuda,
      mesesParaFondoCompleto:
          mesesParaFondoCompleto ?? this.mesesParaFondoCompleto,
    );
  }

  // FIX #3: toString para debugging claro
  @override
  String toString() {
    return 'FinancialProjection(\n'
        '  ingresoPromedio: $ingresoPromedio\n'
        '  gastoPromedio: $gastoPromedio\n'
        '  ahorroMensual: $ahorroMensual\n'
        '  ahorro12Meses: $ahorro12Meses\n'
        '  mesesDeuda: $mesesParaSalirDeDeuda\n'
        '  mesesFondo: $mesesParaFondoCompleto\n'
        ')';
  }
}
