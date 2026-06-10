class FinancialRecommendation {
  final String titulo;
  final String descripcion;
  final String impacto;

  FinancialRecommendation({
    required this.titulo,
    required this.descripcion,
    required this.impacto,
  });

  // FIX #1: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'impacto': impacto,
    };
  }

  factory FinancialRecommendation.fromMap(Map<String, dynamic> map) {
    return FinancialRecommendation(
      titulo: map['titulo'] as String,
      descripcion: map['descripcion'] as String,
      impacto: map['impacto'] as String,
    );
  }

  // FIX #2: copyWith
  FinancialRecommendation copyWith({
    String? titulo,
    String? descripcion,
    String? impacto,
  }) {
    return FinancialRecommendation(
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      impacto: impacto ?? this.impacto,
    );
  }

  // FIX #3: toString
  @override
  String toString() =>
      'FinancialRecommendation(titulo: $titulo, impacto: $impacto)';
}
