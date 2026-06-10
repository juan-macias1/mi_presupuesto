/// Movimiento — registro individual de ingreso o gasto.
///
/// Estado del campo `esDeuda`: histórico. Los movimientos NUEVOS se registran
/// solo como gastos operativos (fijo/variable). Los pagos a deudas se
/// manejan por aparte en la tabla `deudas`. Pero los movimientos antiguos
/// con `es_deuda = 1` se preservan; los motores los ignoran al sumar.
class Movimiento {
  final int? id;
  final String tipo;
  final String categoria;
  final String descripcion;
  final double valor;
  final DateTime fecha;
  final bool esFijo;
  final bool esDeuda;
  final String? acreedor;

  Movimiento({
    this.id,
    required String tipo,
    required this.categoria,
    this.descripcion = '',
    required double valor,
    required this.fecha,
    this.esFijo = false,
    this.esDeuda = false,
    String? acreedor,
  })  : tipo = tipo.toLowerCase().trim(),
        // valor siempre positivo (el signo lo da `tipo`)
        valor = valor.abs(),
        // acreedor solo tiene sentido si es deuda
        acreedor = esDeuda ? acreedor : null,
        // invariante: deuda y gasto fijo son mutuamente excluyentes
        assert(
          !(esDeuda && esFijo),
          'Un movimiento no puede ser deuda y gasto fijo al mismo tiempo.',
        );

  /// Crea un Movimiento desde un mapa de SQLite.
  factory Movimiento.fromMap(Map<String, dynamic> map) {
    final esDeuda = (map['es_deuda'] ?? 0) == 1;
    final esFijo = (map['es_fijo'] ?? 0) == 1;

    return Movimiento(
      id: map['id'] as int?,
      tipo: map['tipo'] as String,
      categoria: map['categoria'] as String,
      descripcion: map['descripcion'] as String? ?? '',
      // SQLite puede retornar int o double para columnas REAL
      valor: (map['valor'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      esFijo: esFijo,
      esDeuda: esDeuda,
      acreedor: esDeuda ? map['acreedor'] as String? : null,
    );
  }

  /// Convierte a mapa para INSERT en BD (sin id — lo genera SQLite).
  Map<String, dynamic> toMap() {
    return {
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'valor': valor,
      'fecha': fecha.toIso8601String(),
      'es_fijo': esFijo ? 1 : 0,
      'es_deuda': esDeuda ? 1 : 0,
      'acreedor': acreedor,
    };
  }

  /// Convierte a mapa para UPDATE en BD (incluye id y fecha).
  Map<String, dynamic> toMapForUpdate() {
    return {
      'id': id,
      'tipo': tipo,
      'categoria': categoria,
      'descripcion': descripcion,
      'valor': valor,
      'fecha': fecha.toIso8601String(),
      'es_fijo': esFijo ? 1 : 0,
      'es_deuda': esDeuda ? 1 : 0,
      'acreedor': acreedor,
    };
  }

  Movimiento copyWith({
    int? id,
    String? tipo,
    String? categoria,
    String? descripcion,
    double? valor,
    DateTime? fecha,
    bool? esFijo,
    bool? esDeuda,
    String? acreedor,
  }) {
    return Movimiento(
      id: id ?? this.id,
      tipo: tipo ?? this.tipo,
      categoria: categoria ?? this.categoria,
      descripcion: descripcion ?? this.descripcion,
      valor: valor ?? this.valor,
      fecha: fecha ?? this.fecha,
      esFijo: esFijo ?? this.esFijo,
      esDeuda: esDeuda ?? this.esDeuda,
      acreedor: acreedor ?? this.acreedor,
    );
  }

  @override
  String toString() {
    return 'Movimiento(\n'
        '  id: $id | tipo: $tipo\n'
        '  categoria: $categoria\n'
        '  valor: $valor\n'
        '  fecha: $fecha\n'
        '  esFijo: $esFijo | esDeuda: $esDeuda\n'
        '  acreedor: $acreedor\n'
        ')';
  }
}