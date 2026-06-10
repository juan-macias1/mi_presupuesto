class FinancialBehavior {
  final String titulo;
  final String mensaje;

  FinancialBehavior({required this.titulo, required this.mensaje});

  // copyWith para modificar campos puntuales
  FinancialBehavior copyWith({String? titulo, String? mensaje}) {
    return FinancialBehavior(
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  // toMap para serialización
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'mensaje': mensaje,
    };
  }

  // fromMap para deserialización
  factory FinancialBehavior.fromMap(Map<String, dynamic> map) {
    return FinancialBehavior(
      titulo: map['titulo'] as String,
      mensaje: map['mensaje'] as String,
    );
  }

  @override
  String toString() => 'FinancialBehavior(titulo: $titulo, mensaje: $mensaje)';
}
