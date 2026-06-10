// FIX #5: enum para saludFinanciera — elimina typos silenciosos
enum SaludFinanciera {
  sinDatos,
  critico,
  riesgo,
  ajustado,
  saludable;

  // Para compatibilidad con el código existente que usa strings
  static SaludFinanciera fromString(String valor) {
    switch (valor.toUpperCase()) {
      case 'CRÍTICO':
      case 'CRITICO':
        return SaludFinanciera.critico;
      case 'RIESGO':
        return SaludFinanciera.riesgo;
      case 'AJUSTADO':
        return SaludFinanciera.ajustado;
      case 'SALUDABLE':
        return SaludFinanciera.saludable;
      default:
        return SaludFinanciera.sinDatos;
    }
  }

  String get label {
    switch (this) {
      case SaludFinanciera.sinDatos:
        return 'SIN DATOS';
      case SaludFinanciera.critico:
        return 'CRÍTICO';
      case SaludFinanciera.riesgo:
        return 'RIESGO';
      case SaludFinanciera.ajustado:
        return 'AJUSTADO';
      case SaludFinanciera.saludable:
        return 'SALUDABLE';
    }
  }
}

class FinancialAnalysis {
  final double ingresos;
  final double gastos;
  // FIX #3: gastosFijos explícito — no más derivar fondoEmergencia / 6
  final double gastosFijos;
  final double gastosVariables;
  final double dineroDisponible;

  final double ahorroRecomendado;
  final double pagoDeudaRecomendado;
  final double fondoEmergenciaRecomendado;

  final double totalDeuda;
  final String estrategiaDeuda;

  // Mantenemos String para compatibilidad con UI existente
  // pero agregamos el getter tipado
  final String saludFinanciera;
  final String mensajeSalud;

  final int mesesParaSalirDeDeuda;
  final String prioridadFinanciera;

  // FIX #4: score clampado entre 0 y 100 en el constructor
  final int financialScore;

  FinancialAnalysis({
    required this.ingresos,
    required this.gastos,
    required this.gastosFijos,
    required this.gastosVariables,
    required this.dineroDisponible,
    required this.ahorroRecomendado,
    required this.pagoDeudaRecomendado,
    required this.fondoEmergenciaRecomendado,
    required this.totalDeuda,
    required this.estrategiaDeuda,
    required this.saludFinanciera,
    required this.mensajeSalud,
    required this.mesesParaSalirDeDeuda,
    required this.prioridadFinanciera,
    required int financialScore,
  // FIX #4: clamp garantizado en construcción
  }) : financialScore = financialScore.clamp(0, 100).toInt();

  // FIX #5: getter tipado para usar el enum cuando convenga
  SaludFinanciera get saludTipada =>
      SaludFinanciera.fromString(saludFinanciera);

  // FIX #7: factory para estado vacío/inicial — evita pasar 13 campos a mano
  factory FinancialAnalysis.empty() {
    return FinancialAnalysis(
      ingresos: 0,
      gastos: 0,
      gastosFijos: 0,
      gastosVariables: 0,
      dineroDisponible: 0,
      ahorroRecomendado: 0,
      pagoDeudaRecomendado: 0,
      fondoEmergenciaRecomendado: 0,
      totalDeuda: 0,
      estrategiaDeuda: 'Registra tus movimientos para comenzar',
      saludFinanciera: 'SIN DATOS',
      mensajeSalud: 'Registra ingresos y gastos para ver tu análisis',
      mesesParaSalirDeDeuda: 0,
      prioridadFinanciera: 'Comienza registrando tus movimientos',
      financialScore: 0,
    );
  }

  // FIX #1: toMap para serialización/caché/backup
  Map<String, dynamic> toMap() {
    return {
      'ingresos': ingresos,
      'gastos': gastos,
      'gastos_fijos': gastosFijos,
      'gastos_variables': gastosVariables,
      'dinero_disponible': dineroDisponible,
      'ahorro_recomendado': ahorroRecomendado,
      'pago_deuda_recomendado': pagoDeudaRecomendado,
      'fondo_emergencia_recomendado': fondoEmergenciaRecomendado,
      'total_deuda': totalDeuda,
      'estrategia_deuda': estrategiaDeuda,
      'salud_financiera': saludFinanciera,
      'mensaje_salud': mensajeSalud,
      'meses_para_salir_deuda': mesesParaSalirDeDeuda,
      'prioridad_financiera': prioridadFinanciera,
      'financial_score': financialScore,
    };
  }

  // FIX #1: fromMap para deserialización
  factory FinancialAnalysis.fromMap(Map<String, dynamic> map) {
    return FinancialAnalysis(
      ingresos: (map['ingresos'] as num).toDouble(),
      gastos: (map['gastos'] as num).toDouble(),
      gastosFijos: (map['gastos_fijos'] as num?)?.toDouble() ?? 0,
      gastosVariables: (map['gastos_variables'] as num?)?.toDouble() ?? 0,
      dineroDisponible: (map['dinero_disponible'] as num).toDouble(),
      ahorroRecomendado: (map['ahorro_recomendado'] as num).toDouble(),
      pagoDeudaRecomendado: (map['pago_deuda_recomendado'] as num).toDouble(),
      fondoEmergenciaRecomendado:
          (map['fondo_emergencia_recomendado'] as num).toDouble(),
      totalDeuda: (map['total_deuda'] as num).toDouble(),
      estrategiaDeuda: map['estrategia_deuda'] as String,
      saludFinanciera: map['salud_financiera'] as String,
      mensajeSalud: map['mensaje_salud'] as String,
      mesesParaSalirDeDeuda: map['meses_para_salir_deuda'] as int,
      prioridadFinanciera: map['prioridad_financiera'] as String,
      financialScore: map['financial_score'] as int,
    );
  }

  // FIX #2: copyWith para modificar campos puntuales sin recrear todo
  FinancialAnalysis copyWith({
    double? ingresos,
    double? gastos,
    double? gastosFijos,
    double? gastosVariables,
    double? dineroDisponible,
    double? ahorroRecomendado,
    double? pagoDeudaRecomendado,
    double? fondoEmergenciaRecomendado,
    double? totalDeuda,
    String? estrategiaDeuda,
    String? saludFinanciera,
    String? mensajeSalud,
    int? mesesParaSalirDeDeuda,
    String? prioridadFinanciera,
    int? financialScore,
  }) {
    return FinancialAnalysis(
      ingresos: ingresos ?? this.ingresos,
      gastos: gastos ?? this.gastos,
      gastosFijos: gastosFijos ?? this.gastosFijos,
      gastosVariables: gastosVariables ?? this.gastosVariables,
      dineroDisponible: dineroDisponible ?? this.dineroDisponible,
      ahorroRecomendado: ahorroRecomendado ?? this.ahorroRecomendado,
      pagoDeudaRecomendado: pagoDeudaRecomendado ?? this.pagoDeudaRecomendado,
      fondoEmergenciaRecomendado:
          fondoEmergenciaRecomendado ?? this.fondoEmergenciaRecomendado,
      totalDeuda: totalDeuda ?? this.totalDeuda,
      estrategiaDeuda: estrategiaDeuda ?? this.estrategiaDeuda,
      saludFinanciera: saludFinanciera ?? this.saludFinanciera,
      mensajeSalud: mensajeSalud ?? this.mensajeSalud,
      mesesParaSalirDeDeuda:
          mesesParaSalirDeDeuda ?? this.mesesParaSalirDeDeuda,
      prioridadFinanciera: prioridadFinanciera ?? this.prioridadFinanciera,
      financialScore: financialScore ?? this.financialScore,
    );
  }

  // FIX #6: toString para debugging claro
  @override
  String toString() {
    return 'FinancialAnalysis(\n'
        '  ingresos: $ingresos\n'
        '  gastos: $gastos (fijos: $gastosFijos | variables: $gastosVariables)\n'
        '  totalDeuda: $totalDeuda\n'
        '  dineroDisponible: $dineroDisponible\n'
        '  score: $financialScore/100\n'
        '  salud: $saludFinanciera\n'
        '  prioridad: $prioridadFinanciera\n'
        ')';
  }
}
