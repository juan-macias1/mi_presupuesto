import 'package:flutter/material.dart';
import '../models/master_financial_result.dart';
import '../services/claude_service.dart';

/// ChatIAScreen — interfaz de chat con Fin, el asesor financiero IA.
///
/// Recibe el `MasterFinancialResult` completo del brain. Lo pasa a
/// `ClaudeService.enviarMensaje` que usa `result.contextoIA` como
/// system prompt — una única fuente de contexto.
///
/// El historial vive en memoria solo durante esta sesión. En una
/// fase futura se persistirá en la tabla `conversaciones_ia` para
/// construir el dataset del LLM propio (Stage 3 del roadmap).
class ChatIAScreen extends StatefulWidget {
  final MasterFinancialResult result;

  const ChatIAScreen({super.key, required this.result});

  @override
  State<ChatIAScreen> createState() => _ChatIAScreenState();
}

class _ChatIAScreenState extends State<ChatIAScreen> {
  final ClaudeService _service = ClaudeService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  /// Historial de mensajes en formato compatible con la Anthropic API:
  /// cada item es `{'role': 'user'|'assistant', 'content': '...'}`.
  final List<Map<String, String>> _historial = [];

  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    // Mensaje inicial de Fin
    _historial.add({
      'role': 'assistant',
      'content':
          '¡Hola! Soy Fin, tu asesor financiero. Pregúntame lo que quieras '
          'sobre tus finanzas — ya tengo todo el contexto de tu situación actual.',
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final mensaje = _inputCtrl.text.trim();
    if (mensaje.isEmpty || _enviando) return;

    setState(() {
      _historial.add({'role': 'user', 'content': mensaje});
      _enviando = true;
      _inputCtrl.clear();
    });

    _scrollAlFinal();

    final respuesta = await _service.enviarMensaje(
      mensaje: mensaje,
      // Pasamos historial sin el mensaje recién añadido porque la API lo
      // espera por separado — claude_service ya lo incluye internamente.
      historial: _historial.sublist(0, _historial.length - 1),
      result: widget.result,
    );

    if (!mounted) return;

    setState(() {
      _historial.add({'role': 'assistant', 'content': respuesta});
      _enviando = false;
    });

    _scrollAlFinal();
  }

  void _scrollAlFinal() {
    // Delay para esperar que el ListView se reconstruya con el nuevo item.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fin · Asesor IA'),
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: _historial.length + (_enviando ? 1 : 0),
              itemBuilder: (context, index) {
                if (_enviando && index == _historial.length) {
                  return const _IndicadorEscribiendo();
                }
                final msg = _historial[index];
                final esUsuario = msg['role'] == 'user';
                return _BurbujaMensaje(
                  texto: msg['content'] ?? '',
                  esUsuario: esUsuario,
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputCtrl,
            enviando: _enviando,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

/// Burbuja de un mensaje individual (usuario o asistente).
class _BurbujaMensaje extends StatelessWidget {
  final String texto;
  final bool esUsuario;

  const _BurbujaMensaje({required this.texto, required this.esUsuario});

  @override
  Widget build(BuildContext context) {
    final color = esUsuario
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFE8E8E8);
    final colorTexto = esUsuario ? Colors.white : Colors.black87;
    final alignment = esUsuario ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(esUsuario ? 16 : 4),
            bottomRight: Radius.circular(esUsuario ? 4 : 16),
          ),
        ),
        child: Text(
          texto,
          style: TextStyle(color: colorTexto, fontSize: 15, height: 1.35),
        ),
      ),
    );
  }
}

/// Indicador "Fin está escribiendo..." que se muestra mientras se espera respuesta.
class _IndicadorEscribiendo extends StatelessWidget {
  const _IndicadorEscribiendo();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text('Fin está pensando...',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

/// Barra inferior con TextField + botón de enviar.
class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enviando;
  final VoidCallback onEnviar;

  const _InputBar({
    required this.controller,
    required this.enviando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !enviando,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Preguntale a Fin...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: enviando ? null : onEnviar,
              elevation: 0,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
