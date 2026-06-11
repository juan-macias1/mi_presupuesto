import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/master_financial_result.dart';

/// ClaudeService — capa HTTP que habla con la Anthropic API.
///
/// Esta versión recibe un `MasterFinancialResult` completo y usa
/// `result.contextoIA` directamente como contexto para Claude. Ya no
/// construye su propio contexto financiero — eso queda centralizado en
/// el brain, evitando inconsistencias entre lo que ve Claude y lo que
/// muestra el dashboard.
///
/// La API key se lee desde `.env` con `flutter_dotenv` — nunca hardcoded.
class ClaudeService {
  static String get _apiKey {
    final key = dotenv.env['ANTHROPIC_API_KEY'];
    if (key == null || key.isEmpty) {
      throw StateError(
        'ANTHROPIC_API_KEY no está configurada. '
        'Verificá que el archivo .env existe y tiene la key, y que está '
        'incluida en assets/ del pubspec.yaml.',
      );
    }
    return key;
  }

  static const String _url = 'https://api.anthropic.com/v1/messages';
  static const String _model = 'claude-sonnet-4-20250514';

  /// Límite del historial conversacional para no explotar el context window.
  static const int _maxMensajesHistorial = 20;

  /// Timeout HTTP — protege al usuario de quedarse esperando.
  static const Duration _timeout = Duration(seconds: 30);

  /// Personalidad e instrucciones del asistente. Separadas del contexto
  /// financiero para mejor procesamiento por parte de Claude.
  static const String _instrucciones = '''
Eres un asesor financiero personal amigable, claro y directo llamado "Fin".
Hablas en español colombiano, de forma cercana pero profesional. Usas "parce" ocasionalmente.
Respondes SIEMPRE basándote en los datos reales del usuario, nunca con consejos genéricos.
Tus respuestas son cortas, claras y accionables. Máximo 3 párrafos.
Usas emojis con moderación para hacer la conversación más amena.
Si te preguntan algo que no tiene que ver con finanzas personales, redirige
amablemente la conversación hacia la situación financiera del usuario.
Nunca inventes datos ni asumas información que no esté en el contexto.
''';

  Future<String> enviarMensaje({
    required String mensaje,
    required List<Map<String, String>> historial,
    required MasterFinancialResult result,
  }) async {
    try {
      final historialLimitado = historial.length > _maxMensajesHistorial
          ? historial.sublist(historial.length - _maxMensajesHistorial)
          : historial;

      final mensajes = [
        ...historialLimitado.map(
          (m) => {"role": m["role"]!, "content": m["content"]!},
        ),
        {"role": "user", "content": mensaje},
      ];

      // System prompt: instrucciones + contexto financiero pre-armado por el brain.
      final systemPrompt = '$_instrucciones\n\n${result.contextoIA}';

      final response = await http
          .post(
            Uri.parse(_url),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': _apiKey,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              "model": _model,
              "max_tokens": 1024,
              "system": systemPrompt,
              "messages": mensajes,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['content'][0]['text'] as String;
      } else if (response.statusCode == 401) {
        return '🔑 Error de autenticación. Verificá la API key en .env.';
      } else if (response.statusCode == 429) {
        return '⏳ Demasiadas solicitudes. Esperá un momento e intentá de nuevo.';
      } else if (response.statusCode >= 500) {
        return '🔧 El servicio de IA está temporalmente caído. Intentá en unos minutos.';
      } else {
        return '⚠️ Error inesperado (${response.statusCode}). Intentá de nuevo.';
      }
    } on http.ClientException {
      return '📡 Sin conexión a internet. Verificá tu red e intentá de nuevo.';
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        return '⌛ La respuesta tardó demasiado. Intentá de nuevo en un momento.';
      }
      return '❌ Error inesperado. Intentá de nuevo.';
    }
  }
}
