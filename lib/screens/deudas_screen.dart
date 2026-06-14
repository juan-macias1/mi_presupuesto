import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/deuda.dart';
import '../models/plan_pago.dart';
import '../services/deuda_engine.dart';
import '../db/database_helper.dart';
import '../theme/app_colors.dart';

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
                    backgroundColor: AppColors.ingreso,
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
                            nuevaSaldo <= 0 ? AppColors.ingreso : null,
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
        backgroundColor: AppColors.gasto,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // ── Resumen general ───────────────────────────────────────
  // ── Resumen general ───────────────────────────────────────
  Widget _buildResumenGeneral() {
    final totalDeuda = _deudas.fold(0.0, (s, d) => s + d.saldoActual);
    final totalInicial = _deudas.fold(0.0, (s, d) => s + d.saldoInicial);
    final yaPagado = totalInicial - totalDeuda;
    final progreso = totalInicial > 0
        ? (yaPagado / totalInicial).clamp(0.0, 1.0).toDouble()
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
            // El número que manda: lo que falta pagar.
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

            // Progreso como hilo fino — comunica sin saturar.
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 1,
                backgroundColor: Colors.grey.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),

            // Contexto secundario: todo en gris, sin competir.
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
  // ── Plan de liberación ────────────────────────────────────
  Widget _buildPlanLiberacion(PlanPago plan) {
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
            // Título neutro: ícono gris, texto negro. Sin color de bloque.
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

            // Los tres datos: todos en gris oscuro, neutros. Jerarquía
            // por tamaño, no por color.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPlanDato(
                  'Libre en',
                  '${plan.mesesParaLiberarse} meses',
                ),
                _buildPlanDato(
                  'Fecha',
                  plan.fechaLiberacion != null
                      ? DateFormat('MMM y', 'es_CO')
                          .format(plan.fechaLiberacion!)
                      : '—',
                ),
                _buildPlanDato(
                  'Cuota',
                  _fmt.format(
                    _deudas.fold(0.0, (s, d) => s + d.cuotaMensual),
                  ),
                ),
              ],
            ),

            // Ataca primero — el único acento naranja, sutil.
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
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Container(
          // El acento de prioridad: un borde lateral naranja, sutil.
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
                // Fila 1: nombre del acreedor (protagonista) + menú.
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
                    PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'pagar',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline,
                                  color: AppColors.ingreso, size: 18),
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
                                  color: AppColors.gasto, size: 18),
                              SizedBox(width: 8),
                              Text('Eliminar',
                                  style: TextStyle(color: AppColors.gasto)),
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
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Eliminar',
                                      style:
                                          TextStyle(color: AppColors.gasto)),
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

                // Descripción + interés como contexto gris en una línea.
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

                // El saldo: importante (rojo) pero el "de X" es contexto gris.
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
                    minHeight: 1,
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
                    Text(
                      'Cuota ${_fmt.format(deuda.cuotaMensual)}/mes',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),

                // Proyección — contexto neutro.
                if (detalle != null) ...[
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
              ],
            ),
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
