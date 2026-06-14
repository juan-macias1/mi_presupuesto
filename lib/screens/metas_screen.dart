import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models/meta_ahorro.dart';
import '../models/meta_inteligente.dart';
import '../services/master_financial_brain.dart';
import '../services/meta_inteligente_engine.dart';
import '../widgets/meta_card.dart';
import '../theme/app_colors.dart';

/// MetasScreen — listado de metas de ahorro con análisis inteligente.
///
/// Carga las metas de la DB y consulta el brain una sola vez para
/// obtener el MasterFinancialResult que necesita el MetaInteligenteEngine.
/// El brain cachea por versión: si nada cambió desde la última llamada,
/// el resultado viene del caché instantáneamente.
class MetasScreen extends StatefulWidget {
  const MetasScreen({super.key});

  @override
  State<MetasScreen> createState() => _MetasScreenState();
}

class _MetasScreenState extends State<MetasScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final MetaInteligenteEngine _engine = MetaInteligenteEngine();

  List<MetaAhorro> _metas = [];
  List<MetaInteligente> _metasAnalizadas = [];
  bool _cargando = true;

  static final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  // ── Carga de datos ────────────────────────────────────────

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    final metasData = await _db.obtenerMetas();
    final metas = metasData.map((m) => MetaAhorro.fromMap(m)).toList();

    // Consultamos al brain — devuelve cache si nada cambió.
    final result = await MasterFinancialBrain.instance.analizar();
    final analizadas = await _engine.analizarMetas(metas, result);

    if (!mounted) return;

    setState(() {
      _metas = metas;
      _metasAnalizadas = analizadas;
      _cargando = false;
    });
  }

  // Empareja una meta con su análisis correspondiente (puede no existir
  // si el motor la filtró por estar inactiva o sin datos).
  MetaInteligente? _analisisDe(MetaAhorro meta) {
    for (final a in _metasAnalizadas) {
      if (a.metaId.toString() == meta.id) return a;
    }
    return null;
  }

  // ── Crear / editar meta ───────────────────────────────────

  void _mostrarFormulario({MetaAhorro? existente}) {
    final esEdicion = existente != null;

    final nombreCtrl = TextEditingController(text: existente?.nombre ?? '');
    final objetivoCtrl = TextEditingController(
      text: existente != null ? existente.montoObjetivo.toStringAsFixed(0) : '',
    );
    final ahorradoCtrl = TextEditingController(
      text: existente != null ? existente.montoAhorrado.toStringAsFixed(0) : '0',
    );
    DateTime fechaObjetivo =
        existente?.fechaObjetivo ?? DateTime.now().add(const Duration(days: 90));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esEdicion ? 'Editar meta' : 'Nueva meta',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nombreCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la meta',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: objetivoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Monto objetivo (COP)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: ahorradoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Monto ya ahorrado (COP)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: sheetContext,
                          initialDate: fechaObjetivo,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365 * 10)),
                          locale: const Locale('es', 'CO'),
                        );
                        if (picked != null) {
                          setSheetState(() => fechaObjetivo = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Fecha objetivo',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('d MMM y', 'es_CO').format(fechaObjetivo),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        if (esEdicion) ...[
                          TextButton.icon(
                            onPressed: () => _confirmarEliminar(
                              sheetContext,
                              existente,
                            ),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.gasto,
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _guardar(
                            sheetContext,
                            existente: existente,
                            nombre: nombreCtrl.text.trim(),
                            objetivoTexto: objetivoCtrl.text,
                            ahorradoTexto: ahorradoCtrl.text,
                            fechaObjetivo: fechaObjetivo,
                          ),
                          child: Text(esEdicion ? 'Guardar' : 'Crear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _guardar(
    BuildContext sheetContext, {
    MetaAhorro? existente,
    required String nombre,
    required String objetivoTexto,
    required String ahorradoTexto,
    required DateTime fechaObjetivo,
  }) async {
    if (nombre.isEmpty) {
      _mostrarError(sheetContext, 'El nombre es obligatorio.');
      return;
    }

    final objetivo = double.tryParse(objetivoTexto.replaceAll(',', ''));
    final ahorrado = double.tryParse(ahorradoTexto.replaceAll(',', '')) ?? 0;

    if (objetivo == null || objetivo <= 0) {
      _mostrarError(sheetContext, 'Monto objetivo inválido.');
      return;
    }
    if (ahorrado < 0) {
      _mostrarError(sheetContext, 'El monto ahorrado no puede ser negativo.');
      return;
    }

    if (existente != null) {
      // UPDATE
      final actualizada = existente.copyWith(
        nombre: nombre,
        montoObjetivo: objetivo,
        montoAhorrado: ahorrado,
        fechaObjetivo: fechaObjetivo,
      );
      await _db.actualizarMeta(actualizada.toMap(), int.parse(existente.id));
    } else {
      // INSERT
      final nueva = MetaAhorro(
        id: '0', // SQLite va a asignar
        nombre: nombre,
        montoObjetivo: objetivo,
        montoAhorrado: ahorrado,
        fechaObjetivo: fechaObjetivo,
        fechaCreacion: DateTime.now(),
      );
      await _db.insertarMeta(nueva.toMapSinId());
    }

    if (!sheetContext.mounted) return;
    Navigator.of(sheetContext).pop();

    await _cargarDatos();
  }

  void _confirmarEliminar(BuildContext sheetContext, MetaAhorro meta) {
    showDialog(
      context: sheetContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar meta'),
        content: Text('¿Eliminar "${meta.nombre}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              await _db.eliminarMeta(int.parse(meta.id));
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              if (!sheetContext.mounted) return;
              Navigator.of(sheetContext).pop();
              await _cargarDatos();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.gasto),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarError(BuildContext ctx, String mensaje) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: AppColors.gasto),
    );
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Metas'),
        elevation: 1,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _mostrarFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva meta'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _metas.isEmpty
              ? _EstadoVacio(onCrear: () => _mostrarFormulario())
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: _metas.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _ResumenMetas(
                          totalMetas: _metas.length,
                          totalObjetivo: _metas.fold<double>(
                            0,
                            (s, m) => s + m.montoObjetivo,
                          ),
                          totalAhorrado: _metas.fold<double>(
                            0,
                            (s, m) => s + m.montoAhorrado,
                          ),
                          formato: _formatoMoneda,
                        );
                      }
                      final meta = _metas[index - 1];
                      return GestureDetector(
                        onTap: () => _mostrarFormulario(existente: meta),
                        child: MetaCard(
                          meta: meta,
                          metaInteligente: _analisisDe(meta),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

/// Header con resumen agregado de todas las metas.
class _ResumenMetas extends StatelessWidget {
  final int totalMetas;
  final double totalObjetivo;
  final double totalAhorrado;
  final NumberFormat formato;

  const _ResumenMetas({
    required this.totalMetas,
    required this.totalObjetivo,
    required this.totalAhorrado,
    required this.formato,
  });

  @override
  Widget build(BuildContext context) {
    final progresoTotal =
        totalObjetivo > 0 ? (totalAhorrado / totalObjetivo).clamp(0.0, 1.0).toDouble() : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$totalMetas ${totalMetas == 1 ? "meta activa" : "metas activas"}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              '${formato.format(totalAhorrado)} de ${formato.format(totalObjetivo)}',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progresoTotal,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(progresoTotal * 100).toStringAsFixed(1)}% del total',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío con CTA para crear la primera meta.
class _EstadoVacio extends StatelessWidget {
  final VoidCallback onCrear;
  const _EstadoVacio({required this.onCrear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flag_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Sin metas todavía',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Las metas te ayudan a darle un destino al ahorro. '
              'Empezá con una pequeña y mensurable.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onCrear,
              icon: const Icon(Icons.add),
              label: const Text('Crear mi primera meta'),
            ),
          ],
        ),
      ),
    );
  }
}
