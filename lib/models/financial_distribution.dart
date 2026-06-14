// FIX #1: enum para fase — elimina typos silenciosos
enum FaseFinanciera {
  sinDatos,
  datosInsuficientes,
  critica,
  moderada,
  estable;

  static FaseFinanciera fromString(String valor) {
    switch (valor.toUpperCase()) {
      case 'DATOS_INSUFICIENTES':
        return FaseFinanciera.datosInsuficientes;
      case 'CRITICA':
        return FaseFinanciera.critica;
      case 'MODERADA':
        return FaseFinanciera.moderada;
      case 'ESTABLE':
        return FaseFinanciera.estable;
      default:
        return FaseFinanciera.sinDatos;
    }
  }

  String get label {
    switch (this) {
      case FaseFinanciera.sinDatos:
        return 'SIN_DATOS';
      case FaseFinanciera.datosInsuficientes:
        return 'DATOS_INSUFICIENTES';
      case FaseFinanciera.critica:
        return 'CRITICA';
      case FaseFinanciera.moderada:
        return 'MODERADA';
      case FaseFinanciera.estable:
        return 'ESTABLE';
    }
  }
}

class FinancialDistribution {
  // Excedente real (ingresos - gastos fijos)
  final double ingresos;
  final double gastosFijos;
  final double excedenteReal;

  // Fase actual del usuario — String para compatibilidad con UI existente
  final String fase;
  final String descripcionFase;

  // Distribución recomendada
  final double porcentajeDeuda;
  final double porcentajeFondo;
  final double porcentajeMetas;

  // Montos concretos
  final double montoDeuda;
  final double montoFondo;
  final double montoMetas;

  // Proyecciones
  final int mesesParaSalirDeDeuda;
  final int mesesParaFondoCompleto;
  final double fondoEmergenciaObjetivo;

  // Mensaje general
  final String mensaje;

  FinancialDistribution({
    required this.ingresos,
    required this.gastosFijos,
    required this.excedenteReal,
    required this.fase,
    required this.descripcionFase,
    required this.porcentajeDeuda,
    required this.porcentajeFondo,
    required this.porcentajeMetas,
    required this.montoDeuda,
    required this.montoFondo,
    required this.montoMetas,
    required this.mesesParaSalirDeDeuda,
    required this.mesesParaFondoCompleto,
    required this.fondoEmergenciaObjetivo,
    required this.mensaje,
  });

  // FIX #1: getter tipado para usar el enum cuando convenga
  FaseFinanciera get faseTipada => FaseFinanciera.fromString(fase);

  /// Estado cuando hay ingresos pero faltan gastos creíbles para calcular
  /// un plan real. No inventamos una distribución sobre un excedente
  /// inflado — pedimos los datos que faltan.
  factory FinancialDistribution.datosInsuficientes({
    required double ingresos,
  }) {
    return FinancialDistribution(
      ingresos: ingresos,
      gastosFijos: 0,
      excedenteReal: 0,
      fase: 'DATOS_INSUFICIENTES',
      descripcionFase:
          'Registra tus gastos del mes para calcular tu plan real.',
      porcentajeDeuda: 0,
      porcentajeFondo: 0,
      porcentajeMetas: 0,
      montoDeuda: 0,
      montoFondo: 0,
      montoMetas: 0,
      mesesParaSalirDeDeuda: 0,
      mesesParaFondoCompleto: 0,
      fondoEmergenciaObjetivo: 0,
      mensaje:
          'Tienes ingresos registrados pero faltan tus gastos del mes. '
          'Cárgalos para que pueda darte un plan de distribución confiable.',
    );
  }

  // FIX #5: factory para estado vacío/inicial
  factory FinancialDistribution.empty() {
    return FinancialDistribution(
      ingresos: 0,
      gastosFijos: 0,
      excedenteReal: 0,
      fase: 'SIN_DATOS',
      descripcionFase: 'Registra tus movimientos para ver tu distribución.',
      porcentajeDeuda: 0,
      porcentajeFondo: 0,
      porcentajeMetas: 0,
      montoDeuda: 0,
      montoFondo: 0,
      montoMetas: 0,
      mesesParaSalirDeDeuda: 0,
      mesesParaFondoCompleto: 0,
      fondoEmergenciaObjetivo: 0,
      mensaje: 'Comienza registrando tus ingresos y gastos fijos.',
    );
  }

  // FIX #2: toMap para serialización
  Map<String, dynamic> toMap() {
    return {
      'ingresos': ingresos,
      'gastos_fijos': gastosFijos,
      'excedente_real': excedenteReal,
      'fase': fase,
      'descripcion_fase': descripcionFase,
      'porcentaje_deuda': porcentajeDeuda,
      'porcentaje_fondo': porcentajeFondo,
      'porcentaje_metas': porcentajeMetas,
      'monto_deuda': montoDeuda,
      'monto_fondo': montoFondo,
      'monto_metas': montoMetas,
      'meses_para_salir_deuda': mesesParaSalirDeDeuda,
      'meses_para_fondo_completo': mesesParaFondoCompleto,
      'fondo_emergencia_objetivo': fondoEmergenciaObjetivo,
      'mensaje': mensaje,
    };
  }

  // FIX #2: fromMap para deserialización
  factory FinancialDistribution.fromMap(Map<String, dynamic> map) {
    return FinancialDistribution(
      ingresos: (map['ingresos'] as num).toDouble(),
      gastosFijos: (map['gastos_fijos'] as num).toDouble(),
      excedenteReal: (map['excedente_real'] as num).toDouble(),
      fase: map['fase'] as String,
      descripcionFase: map['descripcion_fase'] as String,
      porcentajeDeuda: (map['porcentaje_deuda'] as num).toDouble(),
      porcentajeFondo: (map['porcentaje_fondo'] as num).toDouble(),
      porcentajeMetas: (map['porcentaje_metas'] as num).toDouble(),
      montoDeuda: (map['monto_deuda'] as num).toDouble(),
      montoFondo: (map['monto_fondo'] as num).toDouble(),
      montoMetas: (map['monto_metas'] as num).toDouble(),
      mesesParaSalirDeDeuda: map['meses_para_salir_deuda'] as int,
      mesesParaFondoCompleto: map['meses_para_fondo_completo'] as int,
      fondoEmergenciaObjetivo: (map['fondo_emergencia_objetivo'] as num).toDouble(),
      mensaje: map['mensaje'] as String,
    );
  }

  // FIX #3: copyWith para modificar campos puntuales
  FinancialDistribution copyWith({
    double? ingresos,
    double? gastosFijos,
    double? excedenteReal,
    String? fase,
    String? descripcionFase,
    double? porcentajeDeuda,
    double? porcentajeFondo,
    double? porcentajeMetas,
    double? montoDeuda,
    double? montoFondo,
    double? montoMetas,
    int? mesesParaSalirDeDeuda,
    int? mesesParaFondoCompleto,
    double? fondoEmergenciaObjetivo,
    String? mensaje,
  }) {
    return FinancialDistribution(
      ingresos: ingresos ?? this.ingresos,
      gastosFijos: gastosFijos ?? this.gastosFijos,
      excedenteReal: excedenteReal ?? this.excedenteReal,
      fase: fase ?? this.fase,
      descripcionFase: descripcionFase ?? this.descripcionFase,
      porcentajeDeuda: porcentajeDeuda ?? this.porcentajeDeuda,
      porcentajeFondo: porcentajeFondo ?? this.porcentajeFondo,
      porcentajeMetas: porcentajeMetas ?? this.porcentajeMetas,
      montoDeuda: montoDeuda ?? this.montoDeuda,
      montoFondo: montoFondo ?? this.montoFondo,
      montoMetas: montoMetas ?? this.montoMetas,
      mesesParaSalirDeDeuda:
          mesesParaSalirDeDeuda ?? this.mesesParaSalirDeDeuda,
      mesesParaFondoCompleto:
          mesesParaFondoCompleto ?? this.mesesParaFondoCompleto,
      fondoEmergenciaObjetivo:
          fondoEmergenciaObjetivo ?? this.fondoEmergenciaObjetivo,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  // FIX #4: toString para debugging claro
  @override
  String toString() {
    return 'FinancialDistribution(\n'
        '  fase: $fase\n'
        '  ingresos: $ingresos | gastosFijos: $gastosFijos\n'
        '  excedenteReal: $excedenteReal\n'
        '  deuda: $montoDeuda (${(porcentajeDeuda * 100).toStringAsFixed(0)}%)\n'
        '  fondo: $montoFondo (${(porcentajeFondo * 100).toStringAsFixed(0)}%)\n'
        '  metas: $montoMetas (${(porcentajeMetas * 100).toStringAsFixed(0)}%)\n'
        ')';
  }
}
