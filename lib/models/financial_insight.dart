// FIX #1: enum para nivel — elimina typos silenciosos en color/ícono de la UI
enum NivelInsight {
  neutro,
  positivo,
  alerta;

  static NivelInsight fromString(String valor) {
    switch (valor.toLowerCase()) {
      case 'positivo':
        return NivelInsight.positivo;
      case 'alerta':
        return NivelInsight.alerta;
      default:
        return NivelInsight.neutro;
    }
  }

  String get label {
    switch (this) {
      case NivelInsight.neutro:
        return 'neutro';
      case NivelInsight.positivo:
        return 'positivo';
      case NivelInsight.alerta:
        return 'alerta';
    }
  }
}

class FinancialInsight {
  final String titulo;
  final String mensaje;
  // String para compatibilidad con UI existente
  final String nivel;

  FinancialInsight({
    required this.titulo,
    required this.mensaje,
    required this.nivel,
  });

  // FIX #1: getter tipado para usar el enum cuando convenga
  NivelInsight get nivelTipado => NivelInsight.fromString(nivel);

  // FIX #2: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'titulo': titulo,
      'mensaje': mensaje,
      'nivel': nivel,
    };
  }

  factory FinancialInsight.fromMap(Map<String, dynamic> map) {
    return FinancialInsight(
      titulo: map['titulo'] as String,
      mensaje: map['mensaje'] as String,
      nivel: map['nivel'] as String,
    );
  }

  // FIX #3: copyWith
  FinancialInsight copyWith({
    String? titulo,
    String? mensaje,
    String? nivel,
  }) {
    return FinancialInsight(
      titulo: titulo ?? this.titulo,
      mensaje: mensaje ?? this.mensaje,
      nivel: nivel ?? this.nivel,
    );
  }

  // FIX #4: toString
  @override
  String toString() =>
      'FinancialInsight(nivel: $nivel, titulo: $titulo)';
}
