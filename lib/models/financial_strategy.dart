class FinancialStrategy {
  final String titulo;
  final String descripcion;

  FinancialStrategy({required this.titulo, required this.descripcion});

  // FIX #1: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
    };
  }

  factory FinancialStrategy.fromMap(Map<String, dynamic> map) {
    return FinancialStrategy(
      titulo: map['titulo'] as String,
      descripcion: map['descripcion'] as String,
    );
  }

  // FIX #2: copyWith
  FinancialStrategy copyWith({String? titulo, String? descripcion}) {
    return FinancialStrategy(
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
    );
  }

  // FIX #3: toString
  @override
  String toString() =>
      'FinancialStrategy(titulo: $titulo)';
}
