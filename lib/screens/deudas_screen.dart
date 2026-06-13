import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/deuda.dart';
import '../models/plan_pago.dart';
import '../services/deuda_engine.dart';
import '../db/database_helper.dart';

class DeudasScreen extends StatefulWidget {
  const DeudasScreen({super.key});

  @override
  State<DeudasScreen> createState() => _DeudasScreenState();
}

class _DeudasScreenState extends State<DeudasScreen> {
  final _engine = DeudaEngine();
  final _db = DatabaseHelper.instance;

  static final _fmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  List<Deuda> _deudas = [];
  PlanPago? _plan;
  bool _cargando = true;

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

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);

    final deudasData = await _db.obtenerDeudas();
    final deudas = deudasData.map((d) => Deuda.fromMap(d)).toList();

    // Pago disponible = suma de cuotas + cualquier excedente
    final cuotasBase = deudas.fold(0.0, (s, d) => s + d.cuotaMensual);
    final plan = await _engine.generarPlanPago(cuotasBase);

    setState(() {
      _deudas = deudas;
      _plan = plan;
      _cargando = false;
    });
  }

  // ── Agregar deuda ─────────────────────────────────────────
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
                      backgroundColor: Colors.red.shade600,
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

  // ── Registrar pago ────────────────────────────────────────
  void _mostrarRegistrarPago(Deuda deuda) {
    final pagoCtrl = TextEditingController(
      text: deuda.cuotaMensual.toStringAsFixed(0),
    );

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Registrar pago — ${deuda.acreedor}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saldo actual: ${_fmt.format(deuda.saldoActual)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pagoCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: '¿Cuánto pagaste?',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirmar pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final monto = double.tryParse(pagoCtrl.text) ?? 0;
                    if (monto <= 0) return;

                    await _engine.registrarPago(deuda.id!, monto);

                    if (!mounted) return;
                    Navigator.pop(context);
                    await _cargarDatos();

                    final nuevaSaldo = deuda.saldoActual - monto;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nuevaSaldo <= 0
                              ? '🎉 ¡Deuda con ${deuda.acreedor} pagada!'
                              : 'Pago registrado ✅ Saldo: ${_fmt.format(nuevaSaldo)}',
                        ),
                        backgroundColor:
                            nuevaSaldo <= 0 ? Colors.green : null,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
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
                    '¿Cuánto tiempo ahorras si pagas más cada mes?',
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
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
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
                                Colors.orange,
                              ),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.grey,
                              ),
                              _buildSimuladorDato(
                                'Con extra',
                                '${resultado!['mesesConExtra']} meses',
                                Colors.green,
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
        title: const Text('Mis Deudas'),
        actions: [
          if (_deudas.isNotEmpty)
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
          : _deudas.isEmpty
          ? _buildEstadoVacio()
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Resumen general
                  _buildResumenGeneral(),
                  const SizedBox(height: 16),

                  // Plan de liberación
                  if (_plan != null) _buildPlanLiberacion(_plan!),
                  const SizedBox(height: 16),

                  // Lista de deudas
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
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioDeuda(),
        tooltip: 'Agregar deuda',
        backgroundColor: Colors.red.shade400,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Resumen general ───────────────────────────────────────
  Widget _buildResumenGeneral() {
    final totalDeuda = _deudas.fold(0.0, (s, d) => s + d.saldoActual);
    final totalInicial = _deudas.fold(0.0, (s, d) => s + d.saldoInicial);
    final progreso = totalInicial > 0
        ? ((totalInicial - totalDeuda) / totalInicial).clamp(0.0, 1.0).toDouble()
        : 0.0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Deuda total',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _fmt.format(totalDeuda),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Ya pagaste',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _fmt.format(totalInicial - totalDeuda),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Progreso total',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  '${(progreso * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 10,
                backgroundColor: Colors.red.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Plan de liberación ────────────────────────────────────
  Widget _buildPlanLiberacion(PlanPago plan) {
    if (plan.esInsuficiente) {
      return Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.warning_rounded, color: Colors.red),
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

    Color colorEstrategia;
    IconData iconoEstrategia;

    switch (plan.estrategia) {
      case 'SPRINT':
        colorEstrategia = Colors.green;
        iconoEstrategia = Icons.rocket_launch_outlined;
        break;
      case 'AGRESIVA':
        colorEstrategia = Colors.teal;
        iconoEstrategia = Icons.local_fire_department_outlined;
        break;
      case 'PROGRESIVA':
        colorEstrategia = Colors.orange;
        iconoEstrategia = Icons.trending_up;
        break;
      default:
        colorEstrategia = Colors.blueGrey;
        iconoEstrategia = Icons.flag_outlined;
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconoEstrategia, color: colorEstrategia, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Plan de liberación',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: colorEstrategia,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              plan.mensajeEstrategia,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPlanDato(
                  '📅 Libre en',
                  '${plan.mesesParaLiberarse} meses',
                  colorEstrategia,
                ),
                _buildPlanDato(
                  '🗓️ Fecha',
                  plan.fechaLiberacion != null
                      ? DateFormat('MMM y', 'es_CO')
                            .format(plan.fechaLiberacion!)
                      : '—',
                  Colors.blueGrey,
                ),
                _buildPlanDato(
                  '💰 Cuotas',
                  _fmt.format(
                    _deudas.fold(0.0, (s, d) => s + d.cuotaMensual),
                  ),
                  Colors.red,
                ),
              ],
            ),

            // Deuda prioritaria
            if (plan.detallePorDeuda.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(
                    Icons.priority_high,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ataca primero: ${plan.detallePorDeuda.first.acreedor}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanDato(String label, String valor, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // ── Lista de deudas ───────────────────────────────────────
  List<Widget> _buildListaDeudas() {
    return _deudas.map((deuda) {
      final esPrioridad = _plan?.detallePorDeuda.isNotEmpty == true &&
          _plan!.detallePorDeuda.first.deudaId == deuda.id;

      final detalle = _plan?.detallePorDeuda
          .where((d) => d.deudaId == deuda.id)
          .firstOrNull;

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: esPrioridad ? 3 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: esPrioridad
              ? const BorderSide(color: Colors.orange, width: 2)
              : BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (esPrioridad)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'PRIORITARIA',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (deuda.tasaInteres > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${deuda.tasaInteres}% interés',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      deuda.acreedor,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'pagar',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: Colors.green, size: 18),
                            SizedBox(width: 8),
                            Text('Registrar pago'),
                          ],
                        ),
                      ),
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
                                color: Colors.red, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Eliminar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
                    onSelected: (value) async {
                      if (value == 'pagar') {
                        _mostrarRegistrarPago(deuda);
                      } else if (value == 'editar') {
                        _mostrarFormularioDeuda(deudaExistente: deuda);
                      } else if (value == 'eliminar') {
                        final confirmar = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Eliminar deuda'),
                            content: Text(
                              '¿Eliminar la deuda con ${deuda.acreedor}?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, false),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(ctx, true),
                                child: const Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirmar == true) {
                          await _db.eliminarDeuda(deuda.id!);
                          await _cargarDatos();
                        }
                      }
                    },
                  ),
                ],
              ),

              if (deuda.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  deuda.descripcion,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Progreso de la deuda
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _fmt.format(deuda.saldoActual),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
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
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: deuda.porcentajePagado,
                  minHeight: 8,
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(deuda.porcentajePagado * 100).toStringAsFixed(1)}% pagado',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'Cuota: ${_fmt.format(deuda.cuotaMensual)}/mes',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),

              // Proyección del motor
              if (detalle != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '📅 Libre en ${detalle.mesesParaPagar} meses',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        DateFormat('MMM y', 'es_CO')
                            .format(detalle.fechaEstimadaPago),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
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
    }).toList();
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
                backgroundColor: Colors.red.shade400,
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
