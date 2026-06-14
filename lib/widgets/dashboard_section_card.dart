import 'package:flutter/material.dart';

class DashboardSectionCard extends StatefulWidget {
  final String titulo;
  final IconData icono;
  final List<Widget> children;
  final bool inicialmenteExpandido;
  final String? resumen;

  const DashboardSectionCard({
    super.key,
    required this.titulo,
    required this.icono,
    required this.children,
    // BUG FIX #5: true por defecto para que el contenido sea visible al abrir
    this.inicialmenteExpandido = true,
    this.resumen,
  });

  @override
  State<DashboardSectionCard> createState() => _DashboardSectionCardState();
}

class _DashboardSectionCardState extends State<DashboardSectionCard> {
  late bool _expandido;

  @override
  void initState() {
    super.initState();
    _expandido = widget.inicialmenteExpandido;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _expandido = !_expandido),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    widget.icono,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.titulo,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.resumen != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.resumen!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey,
                  ),
                ],
              ),

              // Contenido colapsable
              if (_expandido) ...[
                const SizedBox(height: 16),
                ...widget.children,
              ],
            ],
          ),
        ),
      ),
    );
  }
}