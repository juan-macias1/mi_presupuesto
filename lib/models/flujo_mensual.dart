/// FlujoMensual — corazón de la arquitectura.
///
/// Calcula los números del mes actual UNA SOLA VEZ. Todos los motores
/// y vistas consumen este objeto en lugar de recalcular por su cuenta,
/// lo que elimina inconsistencias entre componentes.
class FlujoMensual {
  final double ingresos;
  final double gastosFijos;
  final double gastosVariables;

  /// Suma de cuotas mínimas de la tabla deudas (no movimientos).
  final double cuotasDeuda;

  /// Saldo real pendiente (no la suma de cuotas acumuladas).
  final double totalDeudaReal;

  const FlujoMensual({
    required this.ingresos,
    required this.gastosFijos,
    required this.gastosVariables,
    required this.cuotasDeuda,
    required this.totalDeudaReal,
  });

  // ── Derivados calculados una sola vez ─────────────────────

  /// Gastos operativos = fijos + variables (sin deuda).
  double get gastosOperativos => gastosFijos + gastosVariables;

  /// Lo que queda después de gastos operativos y cuotas de deuda.
  double get disponibleNeto => ingresos - gastosOperativos - cuotasDeuda;

  /// Dinero libre para atacar deuda extra (sobre las cuotas mínimas).
  double get disponibleParaDeuda =>
      disponibleNeto > 0 ? disponibleNeto * 0.6 : 0.0;

  /// Dinero libre para ahorro/inversión (después de cubrir deuda agresiva).
  double get disponibleParaAhorro =>
      disponibleNeto > 0 ? disponibleNeto * 0.4 : 0.0;

  /// Ratio de gastos operativos sobre ingresos (sin deuda).
  ///
  /// FIX: `.toDouble()` al final es obligatorio. `.clamp()` está definido
  /// en `num`, así que aunque se llame sobre un `double` con argumentos
  /// `double`, el tipo estático de retorno es `num`. Sin el cast,
  /// asignar el resultado a una variable o getter `double` falla con
  /// "num can't be assigned to double".
  double get ratioGastoOperativo => ingresos > 0
      ? (gastosOperativos / ingresos).clamp(0.0, 1.0).toDouble()
      : 0.0;

  /// Ratio de deuda sobre ingresos.
  double get ratioDeuda => ingresos > 0
      ? (totalDeudaReal / ingresos).clamp(0.0, double.infinity).toDouble()
      : 0.0;

  /// Fondo de emergencia ideal = 6 meses de gastos fijos.
  double get fondoEmergenciaIdeal => gastosFijos * 6;

  /// true si los ingresos no alcanzan para cubrir gastos fijos + cuotas.
  bool get enSupervivencia => ingresos < (gastosFijos + cuotasDeuda);

  /// true si hay excedente real para atacar deuda.
  bool get puedeAtacarDeuda =>
      disponibleParaDeuda > 0 && totalDeudaReal > 0;

  // ── Factories ─────────────────────────────────────────────

  factory FlujoMensual.empty() {
    return const FlujoMensual(
      ingresos: 0,
      gastosFijos: 0,
      gastosVariables: 0,
      cuotasDeuda: 0,
      totalDeudaReal: 0,
    );
  }

  factory FlujoMensual.fromMap(Map<String, dynamic> map) {
    return FlujoMensual(
      ingresos: (map['ingresos'] as num).toDouble(),
      gastosFijos: (map['gastos_fijos'] as num).toDouble(),
      gastosVariables: (map['gastos_variables'] as num).toDouble(),
      cuotasDeuda: (map['cuotas_deuda'] as num).toDouble(),
      totalDeudaReal: (map['total_deuda_real'] as num).toDouble(),
    );
  }

  /// FIX: el archivo original tenía un literal de mapa colgando sin
  /// la firma del método. Restaurado correctamente acá.
  Map<String, dynamic> toMap() => {
        'ingresos': ingresos,
        'gastos_fijos': gastosFijos,
        'gastos_variables': gastosVariables,
        'cuotas_deuda': cuotasDeuda,
        'total_deuda_real': totalDeudaReal,
      };

  FlujoMensual copyWith({
    double? ingresos,
    double? gastosFijos,
    double? gastosVariables,
    double? cuotasDeuda,
    double? totalDeudaReal,
  }) {
    return FlujoMensual(
      ingresos: ingresos ?? this.ingresos,
      gastosFijos: gastosFijos ?? this.gastosFijos,
      gastosVariables: gastosVariables ?? this.gastosVariables,
      cuotasDeuda: cuotasDeuda ?? this.cuotasDeuda,
      totalDeudaReal: totalDeudaReal ?? this.totalDeudaReal,
    );
  }

  @override
  String toString() => 'FlujoMensual(\n'
      '  ingresos: $ingresos\n'
      '  gastosFijos: $gastosFijos | gastosVariables: $gastosVariables\n'
      '  cuotasDeuda: $cuotasDeuda | totalDeudaReal: $totalDeudaReal\n'
      '  disponibleNeto: $disponibleNeto\n'
      '  disponibleParaDeuda: $disponibleParaDeuda\n'
      ')';
}