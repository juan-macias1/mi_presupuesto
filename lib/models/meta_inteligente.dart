// FIX #1: enum para estado — elimina typos silenciosos en MetaCard
enum EstadoMeta {
  enRiesgo,
  enCamino,
  acelerada,
  cumplida,
  vencida;

  static EstadoMeta fromString(String valor) {
    switch (valor.toUpperCase()) {
      case 'EN_CAMINO':
        return EstadoMeta.enCamino;
      case 'ACELERADA':
        return EstadoMeta.acelerada;
      case 'CUMPLIDA':
        return EstadoMeta.cumplida;
      case 'VENCIDA':
        return EstadoMeta.vencida;
      default:
        return EstadoMeta.enRiesgo;
    }
  }

  String get label {
    switch (this) {
      case EstadoMeta.enRiesgo:
        return 'EN_RIESGO';
      case EstadoMeta.enCamino:
        return 'EN_CAMINO';
      case EstadoMeta.acelerada:
        return 'ACELERADA';
      case EstadoMeta.cumplida:
        return 'CUMPLIDA';
      case EstadoMeta.vencida:
        return 'VENCIDA';
    }
  }
}

class MetaInteligente {
  final String metaId;
  final String nombre;

  // Estado de la meta — String para compatibilidad con UI existente
  final String estado;
  final String descripcionEstado;

  // Proyección real basada en ahorro actual
  final int mesesProyectados;
  final DateTime fechaProyectada;
  final bool llegaraATiempo;

  // Cuánto destinar mensualmente
  final double aporteMensualSugerido;
  final double aporteMensualParaLlegar;

  // Impacto en finanzas
  final double porcentajeDelExcedente;
  final bool esViable;

  // Mensaje personalizado
  final String mensaje;

  MetaInteligente({
    required this.metaId,
    required this.nombre,
    required this.estado,
    required this.descripcionEstado,
    required this.mesesProyectados,
    required this.fechaProyectada,
    required this.llegaraATiempo,
    required this.aporteMensualSugerido,
    required this.aporteMensualParaLlegar,
    required this.porcentajeDelExcedente,
    required this.esViable,
    required this.mensaje,
  });

  // FIX #1: getter tipado para usar el enum cuando convenga
  EstadoMeta get estadoTipado => EstadoMeta.fromString(estado);

  // FIX #2: toMap / fromMap
  Map<String, dynamic> toMap() {
    return {
      'meta_id': metaId,
      'nombre': nombre,
      'estado': estado,
      'descripcion_estado': descripcionEstado,
      'meses_proyectados': mesesProyectados,
      'fecha_proyectada': fechaProyectada.toIso8601String(),
      'llegara_a_tiempo': llegaraATiempo ? 1 : 0,
      'aporte_mensual_sugerido': aporteMensualSugerido,
      'aporte_mensual_para_llegar': aporteMensualParaLlegar,
      'porcentaje_del_excedente': porcentajeDelExcedente,
      'es_viable': esViable ? 1 : 0,
      'mensaje': mensaje,
    };
  }

  factory MetaInteligente.fromMap(Map<String, dynamic> map) {
    return MetaInteligente(
      metaId: map['meta_id'].toString(),
      nombre: map['nombre'] as String,
      estado: map['estado'] as String,
      descripcionEstado: map['descripcion_estado'] as String,
      mesesProyectados: map['meses_proyectados'] as int,
      fechaProyectada: DateTime.parse(map['fecha_proyectada'] as String),
      llegaraATiempo: map['llegara_a_tiempo'] == 1,
      aporteMensualSugerido:
          (map['aporte_mensual_sugerido'] as num).toDouble(),
      aporteMensualParaLlegar:
          (map['aporte_mensual_para_llegar'] as num).toDouble(),
      porcentajeDelExcedente:
          (map['porcentaje_del_excedente'] as num).toDouble(),
      esViable: map['es_viable'] == 1,
      mensaje: map['mensaje'] as String,
    );
  }

  // FIX #3: copyWith
  MetaInteligente copyWith({
    String? metaId,
    String? nombre,
    String? estado,
    String? descripcionEstado,
    int? mesesProyectados,
    DateTime? fechaProyectada,
    bool? llegaraATiempo,
    double? aporteMensualSugerido,
    double? aporteMensualParaLlegar,
    double? porcentajeDelExcedente,
    bool? esViable,
    String? mensaje,
  }) {
    return MetaInteligente(
      metaId: metaId ?? this.metaId,
      nombre: nombre ?? this.nombre,
      estado: estado ?? this.estado,
      descripcionEstado: descripcionEstado ?? this.descripcionEstado,
      mesesProyectados: mesesProyectados ?? this.mesesProyectados,
      fechaProyectada: fechaProyectada ?? this.fechaProyectada,
      llegaraATiempo: llegaraATiempo ?? this.llegaraATiempo,
      aporteMensualSugerido:
          aporteMensualSugerido ?? this.aporteMensualSugerido,
      aporteMensualParaLlegar:
          aporteMensualParaLlegar ?? this.aporteMensualParaLlegar,
      porcentajeDelExcedente:
          porcentajeDelExcedente ?? this.porcentajeDelExcedente,
      esViable: esViable ?? this.esViable,
      mensaje: mensaje ?? this.mensaje,
    );
  }

  // FIX #4: toString
  @override
  String toString() {
    return 'MetaInteligente(\n'
        '  nombre: $nombre\n'
        '  estado: $estado\n'
        '  mesesProyectados: $mesesProyectados\n'
        '  aporteSugerido: $aporteMensualSugerido\n'
        '  llegaraATiempo: $llegaraATiempo\n'
        '  esViable: $esViable\n'
        ')';
  }
}
