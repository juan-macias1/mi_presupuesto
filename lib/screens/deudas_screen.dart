import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/deuda.dart';
import '../models/plan_pago.dart';
import '../models/master_financial_result.dart';
import '../services/master_financial_brain.dart';
import '../services/deuda_engine.dart';
import '../db/database_helper.dart';
import '../helpers/miles_input_formatter.dart';
import '../theme/app_colors.dart';
import 'celebracion_deuda_screen.dart';

/// Pantalla de Deudas.
///
/// Esta versión está alineada con MODELO_FINANCIERO.md:
/// - Los saldos NO se leen crudos de la tabla; vienen del brain, que los
///   reconcilia restando las amortizaciones vinculadas.
/// - No hay "Registrar pago" desde la pantalla. La única puerta de entrada
///   a un pago es el formulario de movimientos (categoría "Deuda").
/// - El plan de liberación no se proyecta sobre datos parciales: si no
///   hay ≥2 meses cerrados con datos completos, se muestra "Aún aprendiendo
///   tu ritmo" en lugar de inventar una fecha.
/// - Las deudas saldadas se conservan abajo en una sección plegable como
///   historial de logros, no se borran.
/// - Eliminar una deuda con pagos vinculados borra TAMBIÉN esos pagos:
///   la plata se asignó a algo que ya no existe; mantenerlos como gastos
///   operativos mentiría sobre el consumo del usuario.
class DeudasScreen extends StatefulWidget {
  const DeudasScreen({super.key});

  @override
  State<DeudasScreen> createState() => _DeudasScreenState();
}

class _DeudasScreenState extends State<DeudasScreen> {
  final _brain = MasterFinancialBrain.instance;
  final _engine = DeudaEngine();
  final _db = DatabaseHelper.instance;

  static final _fmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // Estado: deudas activas (con saldo > 0) y saldadas (saldo = 0), ambas
  // ya reconciliadas. _result trae la señal planConfiable.
  List<Deuda> _activas = [];
  List<Deuda> _saldadas = [];
  MasterFinancialResult? _result;
  PlanPago? _plan;
  bool _cargando = true;
  bool _verSaldadas = false;

  // Total de amortizaciones vinculadas a deudas ACTIVAS. Es la fuente de
  // verdad para el "Ya pagaste" del panel, según MODELO_FINANCIERO.md.
  // Se calcula en _cargarDatos a partir de los movimientos del histórico,
  // así el widget no tiene que tocar la DB en cada rebuild.
  double _amortizacionesActivasMonto = 0;

  // Movimientos vinculados, indexados por deuda_id. Sirve para mostrar el
  // historial de pagos expandible en cada tarjeta. Se calcula una sola
  // vez en _cargarDatos y queda en memoria.
  final Map<int, List<Map<String, dynamic>>> _pagosPorDeudaMap = {};

  // Set de ids de deudas con el historial expandido en pantalla.
  final Set<int> _historialExpandido = {};

  // Controllers formulario
  final _acreedorCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _saldoCtrl = TextEditingController();
  final _cuotaCtrl = TextEditingController();
  final _tasaCtrl = TextEditingController();
  final _pagoExtraCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _acreedorCtrl.dispose();
    _descripcionCtrl.dispose();
    _saldoCtrl.dispose();
    _cuotaCtrl.dispose();
    _tasaCtrl.dispose();
    _pagoExtraCtrl.dispose();
    super.dispose();
  }

  // ── Carga: una sola fuente de verdad (el brain) ──────────
  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    // El brain ya reconcilia los saldos. Le pedimos análisis forzado para
    // tener los datos frescos después de cualquier cambio (registrar pago,
    // editar, eliminar).
    final result = await _brain.analizar(forzar: true);

    // Para tener TODAS las deudas (activas + saldadas) reconciliadas,
    // necesitamos hacer el mismo trabajo que el brain hace internamente
    // pero incluyendo las inactivas. Lo más limpio es leer todas y
    // recalcular saldos con los movimientos del histórico.
    final todasMap = await _db.obtenerTodasLasDeudas();
    final todasCrudas = todasMap.map((d) => Deuda.fromMap(d)).toList();
    final movimientosMap = await _db.obtenerMovimientos();
    final pagosPorDeuda = <int, double>{};
    for (final m in movimientosMap) {
      final did = m['deuda_id'] as int?;
      if (did == null) continue;
      pagosPorDeuda[did] =
          (pagosPorDeuda[did] ?? 0) + (m['valor'] as num).toDouble();
    }
    final todas = todasCrudas.map((d) {
      if (d.id == null) return d;
      final pagado = pagosPorDeuda[d.id!] ?? 0;
      if (pagado <= 0) return d;
      final saldoCalc =
          (d.saldoInicial - pagado).clamp(0.0, d.saldoInicial);
      return d.copyWith(
        saldoActual: saldoCalc,
        activa: saldoCalc > 0,
      );
    }).toList();

    final activas = todas.where((d) => d.saldoActual > 0).toList()
      ..sort((a, b) => a.ordenPago.compareTo(b.ordenPago));
    final saldadas = todas.where((d) => d.saldoActual <= 0).toList();

    // Total de amortizaciones vinculadas a deudas activas: suma directa
    // sobre los movimientos. Fuente de verdad del "Ya pagaste".
    // Al pasar también construyo el mapa pagosPorDeudaMap que alimenta el
    // historial expandible — una sola pasada, dos resultados.
    final idsActivas = activas.map((d) => d.id).whereType<int>().toSet();
    double amortizacionesActivas = 0;
    final nuevoPagosMap = <int, List<Map<String, dynamic>>>{};
    for (final m in movimientosMap) {
      final did = m['deuda_id'] as int?;
      if (did == null) continue;
      nuevoPagosMap.putIfAbsent(did, () => []).add(m);
      if (idsActivas.contains(did)) {
        amortizacionesActivas += (m['valor'] as num).toDouble();
      }
    }
    // Ordenar cada lista de pagos por fecha descendente — más reciente arriba.
    for (final lista in nuevoPagosMap.values) {
      lista.sort((a, b) =>
          (b['fecha'] as String).compareTo(a['fecha'] as String));
    }

    // Plan de pago: el brain ya calculó el modo; usamos el plan que arma
    // el engine sobre el flujo del mes — pero la confianza del plan la
    // controla _result.planConfiable.
    final cuotasBase = activas.fold(0.0, (s, d) => s + d.cuotaMensual);
    final plan = await _engine.generarPlanPago(cuotasBase);

    if (!mounted) return;
    setState(() {
      _activas = activas;
      _saldadas = saldadas;
      _amortizacionesActivasMonto = amortizacionesActivas;
      _pagosPorDeudaMap
        ..clear()
        ..addAll(nuevoPagosMap);
      _result = result;
      _plan = plan;
      _cargando = false;
    });
  }

  /// Total de amortizaciones vinculadas a deudas activas. Lectura barata
  /// del valor precalculado en _cargarDatos.
  double _amortizacionesActivas() => _amortizacionesActivasMonto;

  // ── Formulario crear/editar deuda ────────────────────────
  void _mostrarFormularioDeuda({Deuda? deudaExistente}) {
    if (deudaExistente != null) {
      _acreedorCtrl.text = deudaExistente.acreedor;
      _descripcionCtrl.text = deudaExistente.descripcion;
      _saldoCtrl.text = deudaExistente.saldoActual.toStringAsFixed(0);
      _cuotaCtrl.text = deudaExistente.cuotaMensual.toStringAsFixed(0);
      _tasaCtrl.text = deudaExistente.tasaInteres.toStringAsFixed(1);
    } else {
      _acreedorCtrl.clear();
      _descripcionCtrl.clear();
      _saldoCtrl.clear();
      _cuotaCtrl.clear();
      _tasaCtrl.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deudaExistente != null ? 'Editar deuda' : 'Nueva deuda',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _acreedorCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Acreedor',
                    hintText: 'Ej: Banco, Mamá, Juan',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Ej: Préstamo para computador',
                    prefixIcon: Icon(Icons.notes_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _saldoCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Saldo actual que debes',
                    hintText: 'Ej: 2000000',
                    prefixIcon: Icon(Icons.money_off_outlined),
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _cuotaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cuota mínima mensual',
                    hintText: 'Ej: 300000',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: _tasaCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Tasa de interés mensual % (0 si no tiene)',
                    hintText: 'Ej: 2.5 — déjalo en 0 si es familia/amigos',
                    prefixIcon: Icon(Icons.percent_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: Text(
                      deudaExistente != null
                          ? 'Guardar cambios'
                          : 'Agregar deuda',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gasto,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final acreedor = _acreedorCtrl.text.trim();
                      final saldo = double.tryParse(_saldoCtrl.text) ?? 0;
                      final cuota = double.tryParse(_cuotaCtrl.text) ?? 0;
                      final tasa = double.tryParse(_tasaCtrl.text) ?? 0;

                      if (acreedor.isEmpty || saldo <= 0 || cuota <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Completa acreedor, saldo y cuota mínima.',
                            ),
                          ),
                        );
                        return;
                      }

                      if (deudaExistente != null) {
                        await _db.actualizarDeuda({
                          'id': deudaExistente.id,
                          'acreedor': acreedor,
                          'descripcion': _descripcionCtrl.text,
                          'saldo_inicial': deudaExistente.saldoInicial,
                          'saldo_actual': saldo,
                          'cuota_mensual': cuota,
                          'tasa_interes': tasa,
                          'fecha_inicio':
                              deudaExistente.fechaInicio.toIso8601String(),
                          'activa': 1,
                          'orden_pago': deudaExistente.ordenPago,
                        });
                      } else {
                        await _db.insertarDeuda({
                          'acreedor': acreedor,
                          'descripcion': _descripcionCtrl.text,
                          'saldo_inicial': saldo,
                          'saldo_actual': saldo,
                          'cuota_mensual': cuota,
                          'tasa_interes': tasa,
                          'fecha_inicio': DateTime.now().toIso8601String(),
                          'activa': 1,
                          'orden_pago': 0,
                        });
                      }

                      if (!mounted) return;
                      Navigator.pop(context);
                      await _cargarDatos();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            deudaExistente != null
                                ? 'Deuda actualizada ✅'
                                : 'Deuda agregada ✅',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Abonar al capital: pago extra a una deuda específica ─
  /// Bottom sheet chico para registrar un abono extra al capital de una
  /// deuda. Genera un movimiento vinculado normal (categoría "Deuda",
  /// gasto fijo, deuda_id apuntando a esta deuda). Si el abono lleva la
  /// deuda a saldo cero, dispara la pantalla de celebración.
  void _mostrarAbonarCapital(Deuda deuda) {
    final montoCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Abonar al capital — ${deuda.acreedor}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Saldo actual: ${_fmt.format(deuda.saldoActual)}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: montoCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    inputFormatters: [MilesInputFormatter()],
                    onChanged: (_) => setSheetState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Monto del abono',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.savings_outlined),
                      label: const Text('Registrar abono'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      onPressed: MilesInputFormatter.parse(montoCtrl.text) != null
                          ? () async {
                              final monto = MilesInputFormatter.parse(
                                    montoCtrl.text,
                                  ) ??
                                  0;
                              if (monto <= 0) return;
                              Navigator.pop(sheetContext);
                              await _registrarAbono(deuda, monto);
                            }
                          : null,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Inserta un movimiento vinculado a la deuda y, si el abono salda la
  /// deuda, dispara la pantalla de celebración full-screen.
  Future<void> _registrarAbono(Deuda deuda, double monto) async {
    // Guardar el saldo previo ANTES de tocar nada, para detectar si este
    // abono es el que cierra la deuda.
    final saldoPrevio = deuda.saldoActual;
    final saldoPosterior = saldoPrevio - monto;

    // Insertar el movimiento como amortización: gasto fijo + categoría
    // "Deuda" + deuda_id. Mismo formato que el formulario de movimientos.
    await DatabaseHelper.instance.insertarMovimiento({
      'tipo': 'gasto',
      'categoria': 'Deuda',
      'descripcion': 'Abono al capital',
      'valor': monto,
      'fecha': DateTime.now().toIso8601String(),
      'es_fijo': 1,
      'es_deuda': 0,
      'acreedor': null,
      'deuda_id': deuda.id,
    });

    if (!mounted) return;

    // Si este abono saldó la deuda, mostramos celebración. La detectamos
    // antes de recargar para no perder el estado previo.
    final saldoLa = saldoPrevio > 0 && saldoPosterior <= 0;

    await _cargarDatos();

    if (!mounted) return;

    if (saldoLa) {
      // ¿Es la última deuda activa? Después del recargado, si _activas
      // quedó vacía, sí lo era.
      final esLaUltima = _activas.isEmpty;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CelebracionDeudaScreen(
            acreedor: deuda.acreedor,
            montoSaldado: deuda.saldoInicial,
            esLaUltimaDeuda: esLaUltima,
          ),
          fullscreenDialog: true,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Abono de ${_fmt.format(monto)} registrado. '
            'Nuevo saldo: ${_fmt.format(saldoPosterior)}',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Eliminar deuda: confirmación detallada ───────────────
  /// Cuenta los movimientos vinculados a una deuda y su monto total, y
  /// muestra un diálogo que deja claro el alcance del borrado antes de
  /// ejecutarlo. Si confirma, borra primero los movimientos y después la
  /// deuda — todo en orden para no dejar referencias colgando.
  Future<void> _confirmarEliminarDeuda(Deuda deuda) async {
    // Buscar todos los movimientos vinculados a esta deuda.
    final movimientosMap = await _db.obtenerMovimientos();
    final vinculados = movimientosMap
        .where((m) => m['deuda_id'] == deuda.id)
        .toList();
    final cantPagos = vinculados.length;
    final totalPagos =
        vinculados.fold(0.0, (s, m) => s + (m['valor'] as num).toDouble());

    if (!mounted) return;

    final mensaje = cantPagos == 0
        ? '¿Eliminar la deuda con ${deuda.acreedor}?'
        : 'Esto eliminará la deuda con ${deuda.acreedor} y también '
            '${cantPagos == 1 ? '1 movimiento' : '$cantPagos movimientos'} '
            'asociado${cantPagos == 1 ? '' : 's'} por un total de '
            '${_fmt.format(totalPagos)}. ¿Confirmás?';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar deuda'),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: AppColors.gasto),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    // Borrar primero los movimientos vinculados, después la deuda.
    for (final m in vinculados) {
      await _db.eliminarMovimiento(m['id'] as int);
    }
    await _db.eliminarDeuda(deuda.id!);

    if (!mounted) return;
    await _cargarDatos();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cantPagos == 0
              ? 'Deuda eliminada'
              : 'Deuda y $cantPagos movimiento${cantPagos == 1 ? '' : 's'} eliminados',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Simulador pago extra ──────────────────────────────────
  void _mostrarSimulador() {
    _pagoExtraCtrl.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Map<String, dynamic>? resultado;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 Simulador de pago extra',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¿Cuánto tiempo ahorras si pagas más cada mes? '
                    'El cálculo usa tus saldos reales.',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _pagoExtraCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Pago extra mensual',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () async {
                        final extra =
                            double.tryParse(_pagoExtraCtrl.text) ?? 0;
                        if (extra <= 0) return;

                        final res =
                            await _engine.simularPagoExtra(extra);
                        setModalState(() => resultado = res);
                      },
                      child: const Text('Simular'),
                    ),
                  ),
                  if (resultado != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.ingreso.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.ingreso.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            resultado!['mensaje'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceAround,
                            children: [
                              _buildSimuladorDato(
                                'Sin extra',
                                '${resultado!['mesesActual']} meses',
                                AppColors.deuda,
                              ),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.grey,
                              ),
                              _buildSimuladorDato(
                                'Con extra',
                                '${resultado!['mesesConExtra']} meses',
                                AppColors.ingreso,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSimuladorDato(String label, String valor, Color color) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  // ── BUILD PRINCIPAL ───────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.black,
        elevation: 0,
        title: const Text('Mis Deudas'),
        actions: [
          if (_activas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.calculate_outlined),
              tooltip: 'Simular pago extra',
              onPressed: _mostrarSimulador,
            ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Agregar deuda',
            onPressed: () => _mostrarFormularioDeuda(),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : (_activas.isEmpty && _saldadas.isEmpty)
              ? _buildEstadoVacio()
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_activas.isNotEmpty) ...[
                        _buildResumenGeneral(),
                        const SizedBox(height: 16),
                        if (_plan != null) _buildPlanLiberacion(_plan!),
                        const SizedBox(height: 16),
                        const Text(
                          'Tus deudas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._buildListaDeudas(),
                      ],
                      if (_saldadas.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildSeccionSaldadas(),
                      ],
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioDeuda(),
        tooltip: 'Agregar deuda',
        backgroundColor: AppColors.gasto,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Resumen general ───────────────────────────────────────
  // El "ya pagado" se calcula como suma de amortizaciones vinculadas a
  // deudas ACTIVAS — la fuente de verdad del MODELO_FINANCIERO.md. No
  // hacemos saldo_inicial − saldo_actual porque esos dos campos pueden
  // tener desbalances históricos (intereses no modelados en v1, ediciones
  // pasadas) y la fórmula vieja se rompía. Las amortizaciones son hechos
  // registrados, inmunes a esos desbalances.
  Widget _buildResumenGeneral() {
    final totalDeuda = _activas.fold(0.0, (s, d) => s + d.saldoActual);
    final yaPagado = _amortizacionesActivas();
    final base = yaPagado + totalDeuda; // base honesta para el progreso.
    final progreso = base > 0
        ? (yaPagado / base).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Te falta pagar',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              _fmt.format(totalDeuda),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppColors.gasto,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 14),

            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 2,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progreso * 100).toStringAsFixed(0)}% pagado',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  'Ya pagaste ${_fmt.format(yaPagado)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan de liberación ────────────────────────────────────
  Widget _buildPlanLiberacion(PlanPago plan) {
    final confiable = _result?.planConfiable ?? false;
    final meses = _result?.mesesConfiables ?? 0;

    // Caso 1: no hay datos confiables todavía. Sin proyección — solo el
    // cartel honesto. Las "promesas" llegan cuando hay historial real.
    if (!confiable) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hourglass_empty_rounded,
                  size: 20, color: Colors.grey.shade600),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aún aprendiendo tu ritmo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meses == 0
                          ? 'Necesito al menos 2 meses cerrados con ingresos '
                              'y gastos registrados para calcular tu fecha '
                              'de libertad con honestidad.'
                          : 'Llevo $meses mes con datos completos. Con uno '
                              'más, puedo proyectar tu plan real.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Caso 2: plan insuficiente — los pagos no alcanzan a cubrir los
    // intereses. Mensaje del engine, sin maquillar.
    if (plan.esInsuficiente) {
      return Card(
        elevation: 0,
        color: AppColors.gasto.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded,
                  color: AppColors.gasto, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan.mensajeEstrategia,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Caso 3: plan confiable y viable.
    final iconoEstrategia = switch (plan.estrategia) {
      'SPRINT' => Icons.rocket_launch_outlined,
      'AGRESIVA' => Icons.local_fire_department_outlined,
      'PROGRESIVA' => Icons.trending_up,
      _ => Icons.flag_outlined,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconoEstrategia, color: Colors.grey.shade700, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Plan de liberación',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              plan.mensajeEstrategia,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),

            // Los dos datos clave del plan. La "cuota total" desapareció:
            // sumar cuotas mínimas no aporta información útil al usuario;
            // cada deuda muestra su cuota en su propia tarjeta.
            Row(
              children: [
                Expanded(
                  child: _buildPlanDato(
                    'Libre en',
                    '${plan.mesesParaLiberarse} meses',
                  ),
                ),
                Expanded(
                  child: _buildPlanDato(
                    'Fecha',
                    plan.fechaLiberacion != null
                        ? DateFormat('MMM y', 'es_CO')
                            .format(plan.fechaLiberacion!)
                        : '—',
                  ),
                ),
              ],
            ),

            if (plan.detallePorDeuda.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.deuda.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.arrow_forward,
                        color: AppColors.deuda, size: 15),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Ataca primero: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                            TextSpan(
                              text: plan.detallePorDeuda.first.acreedor,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDato(String label, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // ── Lista de deudas activas ───────────────────────────────
  List<Widget> _buildListaDeudas() {
    return _activas.map((deuda) {
      final esPrioridad = _plan?.detallePorDeuda.isNotEmpty == true &&
          _plan!.detallePorDeuda.first.deudaId == deuda.id;

      final detalle = _plan?.detallePorDeuda
          .where((d) => d.deudaId == deuda.id)
          .firstOrNull;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: esPrioridad
                ? const Border(
                    left: BorderSide(color: AppColors.deuda, width: 3),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila 1: nombre del acreedor + chip prioritaria + menú.
                // Sin "Registrar pago": esa entrada se elimina. El registro
                // de cuotas vive en el formulario de movimientos.
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        deuda.acreedor,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (esPrioridad)
                      Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.deuda.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'prioritaria',
                          style: TextStyle(
                            color: Color(0xFF5F5E5A),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    PopupMenuButton<String>(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  color: AppColors.gasto, size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar',
                                  style: TextStyle(color: AppColors.gasto)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'editar') {
                          _mostrarFormularioDeuda(deudaExistente: deuda);
                        } else if (value == 'eliminar') {
                          await _confirmarEliminarDeuda(deuda);
                        }
                      },
                    ),
                  ],
                ),

                if (deuda.descripcion.isNotEmpty || deuda.tasaInteres > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (deuda.descripcion.isNotEmpty) deuda.descripcion,
                      if (deuda.tasaInteres > 0)
                        '${deuda.tasaInteres}% interés',
                    ].join('  ·  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Saldo reconciliado: lo que realmente debés HOY, después
                // de descontar todas las amortizaciones vinculadas.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _fmt.format(deuda.saldoActual),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gasto,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'de ${_fmt.format(deuda.saldoInicial)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: deuda.porcentajePagado,
                    minHeight: 2,
                    backgroundColor: Colors.grey.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(deuda.porcentajePagado * 100).toStringAsFixed(0)}% pagado',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    // Etiquetado claro: es la cuota mínima de referencia
                    // declarada por el banco, NO un cálculo de la app.
                    Text(
                      'Cuota mínima ${_fmt.format(deuda.cuotaMensual)}/mes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                // Proyección por deuda — solo si el plan general es
                // confiable. Si no, no inventamos fechas individuales.
                if (detalle != null && (_result?.planConfiable ?? false)) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 13, color: Colors.grey.shade500),
                      const SizedBox(width: 6),
                      Text(
                        'Libre en ${detalle.mesesParaPagar} meses',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM y', 'es_CO')
                            .format(detalle.fechaEstimadaPago),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],

                // ── Acciones: abonar al capital + ver historial ──
                // Dos botones discretos en la base de la tarjeta. "Abonar
                // al capital" abre un sheet chico para registrar un pago
                // extra. "Ver pagos" toggle el historial expandible debajo.
                const SizedBox(height: 12),
                _accionesTarjeta(deuda),
                _historialDeuda(deuda),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── Acciones en la base de cada tarjeta (abonar + historial) ───
  Widget _accionesTarjeta(Deuda deuda) {
    final pagos = _pagosPorDeudaMap[deuda.id ?? -1] ?? const [];
    final expandido = _historialExpandido.contains(deuda.id);

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.savings_outlined, size: 16),
            label: const Text('Abonar al capital'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => _mostrarAbonarCapital(deuda),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          icon: Icon(
            expandido ? Icons.expand_less : Icons.expand_more,
            size: 18,
          ),
          label: Text(
            pagos.isEmpty
                ? 'Sin pagos'
                : 'Ver pagos (${pagos.length})',
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey.shade700,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          onPressed: pagos.isEmpty
              ? null
              : () => setState(() {
                    if (expandido) {
                      _historialExpandido.remove(deuda.id);
                    } else if (deuda.id != null) {
                      _historialExpandido.add(deuda.id!);
                    }
                  }),
        ),
      ],
    );
  }

  // Bloque de historial expandido bajo la tarjeta. Solo se renderiza si
  // esta deuda está en _historialExpandido. Lista cronológica descendente.
  Widget _historialDeuda(Deuda deuda) {
    if (!_historialExpandido.contains(deuda.id)) {
      return const SizedBox.shrink();
    }
    final pagos = _pagosPorDeudaMap[deuda.id ?? -1] ?? const [];
    if (pagos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: pagos.map((m) {
            final fecha = DateTime.parse(m['fecha'] as String);
            final desc = (m['descripcion'] as String? ?? '').trim();
            final valor = (m['valor'] as num).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text(
                    DateFormat('d MMM', 'es_CO').format(fecha),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      desc.isEmpty ? 'Pago' : desc,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _fmt.format(valor),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Sección plegable: Deudas saldadas (historial de logros) ───
  Widget _buildSeccionSaldadas() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
      ),
      child: Theme(
        // Quitar el divisor y el ripple gris del ExpansionTile.
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          initiallyExpanded: _verSaldadas,
          onExpansionChanged: (v) => setState(() => _verSaldadas = v),
          leading: Icon(
            Icons.emoji_events_outlined,
            color: AppColors.primary,
            size: 20,
          ),
          title: Text(
            'Deudas saldadas (${_saldadas.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: _saldadas
              .map((d) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    leading: const Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    title: Text(
                      d.acreedor,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      'Saldaste ${_fmt.format(d.saldoInicial)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ── Estado vacío ──────────────────────────────────────────
  Widget _buildEstadoVacio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💳', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              'No tienes deudas registradas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Registra tus deudas para que el motor calcule '
              'el plan más rápido para liberarte.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Agregar primera deuda'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gasto,
                foregroundColor: Colors.white,
              ),
              onPressed: () => _mostrarFormularioDeuda(),
            ),
          ],
        ),
      ),
    );
  }
}
