class MoneyLeak {
  final String categoria;
  final String mensaje;
  final double porcentaje;

  MoneyLeak({
    required this.categoria,
    required this.mensaje,
    required this.porcentaje,
  });

  // FIX #1: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'categoria': categoria,
      'mensaje': mensaje,
      'porcentaje': porcentaje,
    };
  }

  factory MoneyLeak.fromMap(Map<String, dynamic> map) {
    return MoneyLeak(
      categoria: map['categoria'] as String,
      mensaje: map['mensaje'] as String,
      porcentaje: (map['porcentaje'] as num).toDouble(),
    );
  }

  // FIX #2: copyWith
  MoneyLeak copyWith({
    String? categoria,
    String? mensaje,
    double? porcentaje,
  }) {
    return MoneyLeak(
      categoria: categoria ?? this.categoria,
      mensaje: mensaje ?? this.mensaje,
      porcentaje: porcentaje ?? this.porcentaje,
    );
  }

  // FIX #3: toString
  @override
  String toString() =>
      'MoneyLeak(categoria: $categoria, porcentaje: ${(porcentaje * 100).toStringAsFixed(1)}%)';
}
