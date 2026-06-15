/// Movimiento — registro individual de ingreso o gasto.
///
/// Modelo actual del vínculo con deudas (v5):
///
/// Un pago de cuota de deuda es un MOVIMIENTO de gasto fijo (porque
/// la cuota suele ser un valor recurrente y constante) que apunta a
/// la deuda que está pagando vía `deudaId`. Que sea gasto fijo y
/// pago de deuda al mismo tiempo es legítimo y esperado.
///
/// El saldo real de una deuda se calcula como `saldoInicial − suma de
/// movimientos vinculados`, no se guarda como dato fijo. Si se elimina
/// un movimiento, su `deudaId` se preserva y el saldo se recompone solo.
/// Si se elimina la deuda, `deudaId` queda NULL (ON DELETE SET NULL) y
/// el movimiento sigue siendo gasto real — la plata salió igual.
///
/// Campos heredados de modelos anteriores que ya no se usan al registrar
/// movimientos nuevos pero se preservan para datos viejos: `esDeuda` y
/// `acreedor`. Quedan a la espera de una limpieza posterior.
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

  /// Si este movimiento es el pago de una cuota, el id de la deuda
  /// que está pagando. Null si es un gasto/ingreso normal.
  final int? deudaId;

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
    this.deudaId,
  })  : tipo = tipo.toLowerCase().trim(),
        // valor siempre positivo (el signo lo da `tipo`)
        valor = valor.abs(),
        // acreedor solo tiene sentido si es deuda (modelo viejo)
        acreedor = esDeuda ? acreedor : null;

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
      deudaId: map['deuda_id'] as int?,
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
      'deuda_id': deudaId,
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
      'deuda_id': deudaId,
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
    int? deudaId,
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
      deudaId: deudaId ?? this.deudaId,
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
        '  acreedor: $acreedor | deudaId: $deudaId\n'
        ')';
  }
}
