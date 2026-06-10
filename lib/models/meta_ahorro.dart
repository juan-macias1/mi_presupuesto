class MetaAhorro {
  // FIX #5: id documentado explícitamente como String por conversión desde int de SQLite
  final String id;
  final String nombre;
  final double montoObjetivo;
  final double montoAhorrado;
  final DateTime fechaObjetivo;
  final DateTime fechaCreacion;
  final bool activa;

  MetaAhorro({
    required this.id,
    required this.nombre,
    required this.montoObjetivo,
    required this.montoAhorrado,
    required this.fechaObjetivo,
    required this.fechaCreacion,
    this.activa = true,
  });

  // FIX #1 y #4: progreso y porcentaje con guard contra división por cero
  double get progreso => montoObjetivo > 0
      ? (montoAhorrado / montoObjetivo).clamp(0.0, 1.0).toDouble()
      : 0.0;

  double get porcentaje => progreso * 100;

  // Getter de conveniencia
  double get restante => (montoObjetivo - montoAhorrado).clamp(0.0, double.infinity).toDouble();
  bool get cumplida => montoAhorrado >= montoObjetivo;

  factory MetaAhorro.fromMap(Map<String, dynamic> map) {
    return MetaAhorro(
      // FIX #5: conversión explícita y documentada
      id: map['id'].toString(),
      nombre: map['nombre'] as String,
      // FIX #2: cast seguro — SQLite puede retornar int o double
      montoObjetivo: (map['montoObjetivo'] as num).toDouble(),
      montoAhorrado: (map['montoAhorrado'] as num).toDouble(),
      fechaObjetivo: DateTime.parse(map['fechaObjetivo'] as String),
      fechaCreacion: DateTime.parse(map['fechaCreacion'] as String),
      activa: map['activa'] == 1,
    );
  }

  // FIX #3: toMap ahora incluye id para updates en la DB
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'montoObjetivo': montoObjetivo,
      'montoAhorrado': montoAhorrado,
      'fechaObjetivo': fechaObjetivo.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'activa': activa ? 1 : 0,
    };
  }

  // toMapSinId para INSERT — evita pasar id nulo en inserciones nuevas
  Map<String, dynamic> toMapSinId() {
    return {
      'nombre': nombre,
      'montoObjetivo': montoObjetivo,
      'montoAhorrado': montoAhorrado,
      'fechaObjetivo': fechaObjetivo.toIso8601String(),
      'fechaCreacion': fechaCreacion.toIso8601String(),
      'activa': activa ? 1 : 0,
    };
  }

  // FIX #6: copyWith — muy útil para actualizar montoAhorrado sin recrear todo
  MetaAhorro copyWith({
    String? id,
    String? nombre,
    double? montoObjetivo,
    double? montoAhorrado,
    DateTime? fechaObjetivo,
    DateTime? fechaCreacion,
    bool? activa,
  }) {
    return MetaAhorro(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      montoObjetivo: montoObjetivo ?? this.montoObjetivo,
      montoAhorrado: montoAhorrado ?? this.montoAhorrado,
      fechaObjetivo: fechaObjetivo ?? this.fechaObjetivo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      activa: activa ?? this.activa,
    );
  }

  // FIX #7: toString
  @override
  String toString() {
    return 'MetaAhorro(\n'
        '  id: $id | nombre: $nombre\n'
        '  progreso: ${porcentaje.toStringAsFixed(1)}%\n'
        '  $montoAhorrado / $montoObjetivo\n'
        '  fechaObjetivo: $fechaObjetivo\n'
        '  activa: $activa\n'
        ')';
  }
}
