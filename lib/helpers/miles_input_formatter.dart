import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// MilesInputFormatter — formatea un campo numérico con separadores de
/// miles en vivo mientras el usuario escribe (estilo colombiano: 1.500.000).
///
/// El usuario teclea solo dígitos; este formatter inserta los puntos.
/// Para recuperar el valor numérico real, usar `MilesInputFormatter.parse(texto)`,
/// que quita los puntos y devuelve un double.
class MilesInputFormatter extends TextInputFormatter {
  static final NumberFormat _formato = NumberFormat.decimalPattern('es_CO');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Dejar solo dígitos.
    final soloDigitos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (soloDigitos.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // Parsear y reformatear con separadores de miles.
    final numero = int.parse(soloDigitos);
    final formateado = _formato.format(numero);

    // Mantener el cursor al final (lo más simple y predecible para montos).
    return TextEditingValue(
      text: formateado,
      selection: TextSelection.collapsed(offset: formateado.length),
    );
  }

  /// Convierte el texto formateado ("1.500.000") a un double (1500000.0).
  /// Devuelve null si no hay dígitos.
  static double? parse(String texto) {
    final soloDigitos = texto.replaceAll(RegExp(r'[^0-9]'), '');
    if (soloDigitos.isEmpty) return null;
    return double.parse(soloDigitos);
  }

  /// Formatea un double a texto con separadores ("1.500.000"), para
  /// pre-cargar el campo al editar un movimiento existente.
  static String format(double valor) {
    return _formato.format(valor.round());
  }
}
