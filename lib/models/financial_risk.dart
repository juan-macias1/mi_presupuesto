// FIX #1: enum para nivel — elimina typos silenciosos en color/ícono de la UI
enum NivelRiesgo {
  bajo,
  medio,
  alto,
  critico;

  static NivelRiesgo fromString(String valor) {
    switch (valor.toLowerCase()) {
      case 'medio':
        return NivelRiesgo.medio;
      case 'alto':
        return NivelRiesgo.alto;
      case 'critico':
        return NivelRiesgo.critico;
      default:
        return NivelRiesgo.bajo;
    }
  }

  String get label {
    switch (this) {
      case NivelRiesgo.bajo:
        return 'bajo';
      case NivelRiesgo.medio:
        return 'medio';
      case NivelRiesgo.alto:
        return 'alto';
      case NivelRiesgo.critico:
        return 'critico';
    }
  }
}

class FinancialRisk {
  final String titulo;
  final String descripcion;
  // String para compatibilidad con UI existente
  final String nivel;

  FinancialRisk({
    required this.titulo,
    required this.descripcion,
    required this.nivel,
  });

  // FIX #1: getter tipado para usar el enum cuando convenga
  NivelRiesgo get nivelTipado => NivelRiesgo.fromString(nivel);

  // FIX #2: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'nivel': nivel,
    };
  }

  factory FinancialRisk.fromMap(Map<String, dynamic> map) {
    return FinancialRisk(
      titulo: map['titulo'] as String,
      descripcion: map['descripcion'] as String,
      nivel: map['nivel'] as String,
    );
  }

  // FIX #3: copyWith
  FinancialRisk copyWith({
    String? titulo,
    String? descripcion,
    String? nivel,
  }) {
    return FinancialRisk(
      titulo: titulo ?? this.titulo,
      descripcion: descripcion ?? this.descripcion,
      nivel: nivel ?? this.nivel,
    );
  }

  // FIX #4: toString
  @override
  String toString() =>
      'FinancialRisk(nivel: $nivel, titulo: $titulo)';
}
