class CategorySuggestionService {
  // ── Normalización de tildes ───────────────────────────────
  // FIX #5: normalizar antes de comparar, elimina duplicados manuales con/sin tilde
  static String _normalizar(String texto) {
    const conTilde = 'áéíóúüñÁÉÍÓÚÜÑ';
    const sinTilde = 'aeiouunAEIOUUN';
    var resultado = texto.toLowerCase().trim();
    for (var i = 0; i < conTilde.length; i++) {
      resultado = resultado.replaceAll(conTilde[i], sinTilde[i]);
    }
    return resultado;
  }

  // FIX #1: verificar palabra completa con delimitadores
  static bool _contienepalabra(String texto, String palabra) {
    // Busca la palabra rodeada de espacios, inicio o fin de cadena
    final patron = RegExp(
      r'(^|[\s,.\-/])' + RegExp.escape(palabra) + r'($|[\s,.\-/])',
    );
    return patron.hasMatch(texto);
  }

  // ── Reglas locales ────────────────────────────────────────
  // FIX #7: ordenadas por especificidad — las más específicas primero
  // FIX #3: palabras clave colombianas agregadas
  // FIX #4: "droga" reemplazada por términos más precisos
  static const Map<String, List<String>> _reglas = {
    // Más específicas primero
    'Vivienda': [
      'arriendo',
      'alquiler',
      'renta',
      'hipoteca',
      'administracion',
      'cuota administracion',
      'vivienda',
      'apartamento',
      'conjunto',
      'propiedad horizontal',
    ],
    'Salud': [
      'medico',
      'doctor',
      'farmacia',
      'drogueria',
      'medicamento',
      'medicina',
      'hospital',
      'clinica',
      'cita medica',
      'consulta',
      'eps',
      'seguro medico',
      'odontologia',
      'dentista',
      'gym',
      'gimnasio',
      'vitaminas',
      'psicologo',
      'terapia',
      'laboratorio',
      'examen medico',
      'optometria',
      'optica',
    ],
    'Educación': [
      'universidad',
      'colegio',
      'escuela',
      'matricula',
      'curso',
      'libro',
      'libros',
      'cuaderno',
      'utiles',
      'educacion',
      'clase',
      'taller',
      'capacitacion',
      'diploma',
      'certificado',
      'udemy',
      'coursera',
      'platzi',
      'seminario',
      'posgrado',
      'especializacion',
    ],
    'Servicios': [
      'luz',
      'agua',
      'gas natural',
      'internet',
      'telefono',
      'celular',
      'plan celular',
      'netflix',
      'spotify',
      'streaming',
      'suscripcion',
      'cable',
      'television',
      'disney',
      'hbo',
      'amazon prime',
      'youtube premium',
      'crunchyroll',
      'paramount',
      'claro',
      'tigo',
      'movistar',
      'wom',
      'etb',
      'une',
    ],
    'Transporte': [
      'gasolina',
      'combustible',
      'bus',
      'taxi',
      'uber',
      'metro',
      'moto',
      'parqueadero',
      'parking',
      'peaje',
      'transporte',
      'pasaje',
      'cabify',
      'indriver',
      'beat',
      'tren',
      'avion',
      'vuelo',
      'aerolinea',
      'sitp',
      'transmilenio',
      'bicicleta',
      'scooter',
      'patineta',
      'servicio publico',
    ],
    'Alimentación': [
      'comida',
      'almuerzo',
      'desayuno',
      'cena',
      'restaurante',
      'cafe',
      'pizza',
      'hamburguesa',
      'mercado',
      'supermercado',
      'tienda',
      'panaderia',
      'frutas',
      'verduras',
      'rappi',
      'domicilio',
      'ifood',
      'uber eats',
      'snack',
      'helado',
      'dulces',
      'bebidas',
      'd1',
      'ara',
      'exito',
      'jumbo',
      'carulla',
      'oma',
      'mcdonalds',
      'kfc',
      'subway',
      'burger king',
      'frisby',
      'el corral',
    ],
    'Ocio': [
      'cine',
      'teatro',
      'concierto',
      'evento',
      'fiesta',
      'bar',
      'disco',
      'discoteca',
      'juego',
      'videojuego',
      'ropa',
      'zapatos',
      'compras',
      'shopping',
      'viaje',
      'hotel',
      'paseo',
      'vacaciones',
      'deporte',
      'futbol',
      'entrada',
      'peluqueria',
      'barberia',
      'spa',
      'masaje',
      'manicure',
      'pedicure',
      'estetica',
    ],
    // Otros al final — más genérica
    'Otros': [
      'regalo',
      'donacion',
      'multa',
      'impuesto',
      'banco',
      'comision',
      'transferencia',
      'retiro',
      'cajero',
      'notaria',
      'tramite',
    ],
  };

  // ── Sugerir con scoring ───────────────────────────────────
  // FIX #2: en vez de primera que matchea, gana la que tiene más coincidencias
  static String? sugerirPorReglas(String descripcion) {
    if (descripcion.trim().isEmpty) return null;

    final texto = _normalizar(descripcion);

    String? mejorCategoria;
    int mejorScore = 0;

    for (var entry in _reglas.entries) {
      int score = 0;
      for (var palabra in entry.value) {
        final palabraNorm = _normalizar(palabra);
        // Frases con espacios: contains es suficiente
        // Palabras sueltas: verificar que sea palabra completa
        final bool coincide = palabraNorm.contains(' ')
            ? texto.contains(palabraNorm)
            : _contienepalabra(texto, palabraNorm);

        if (coincide) score++;
      }
      if (score > mejorScore) {
        mejorScore = score;
        mejorCategoria = entry.key;
      }
    }

    return mejorCategoria;
  }

  // FIX #6: sugerir() ahora tiene valor real — aquí conectarás Claude como respaldo
  // cuando llegue la API key. Por ahora delega a reglas locales.
  static Future<String?> sugerir(String descripcion) async {
    final local = sugerirPorReglas(descripcion);
    if (local != null) return local;

    // TODO: cuando llegue la API key de Claude, descomentar esto:
    // return await _sugerirConClaude(descripcion);

    return null;
  }

  // ── Placeholder para Claude (listo para activar) ──────────
  // static Future<String?> _sugerirConClaude(String descripcion) async {
  //   // Llamar a ClaudeService con descripcion
  //   // Parsear respuesta y retornar categoría
  //   return null;
  // }

}
