import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_colors.dart';
import 'services/preferences_service.dart';
import 'helpers/miles_input_formatter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'db/database_helper.dart';
import 'helpers/export_helper.dart';
import 'services/google_drive_service.dart';
import 'services/notification_service.dart';
import 'screens/metas_screen.dart';
import 'screens/financial_dashboard_screen.dart';
import 'screens/deudas_screen.dart';
import 'screens/celebracion_deuda_screen.dart';

// Nombre de la categoría "Deuda". Es una categoría ESPECIAL: vive en el
// código, no en la tabla `categorias`, no se puede borrar ni editar desde
// la gestión de categorías. Solo aparece en el selector cuando hay al
// menos una deuda activa. Elegirla dispara el selector de deudas, prende
// el switch "Gasto fijo" sola y guarda el deuda_id en el movimiento.
//
// Conceptualmente esta categoría representa una AMORTIZACIÓN de pasivo,
// no un gasto operativo. Ver MODELO_FINANCIERO.md.
const String kCategoriaDeuda = 'Deuda';
const String kEmojiCategoriaDeuda = '💳';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación en vertical. Una app de finanzas no necesita
  // landscape; bloquearlo elimina toda una clase de bugs de layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Cargar variables de entorno (.env contiene ANTHROPIC_API_KEY).
  // Si falla, seguimos arrancando — el chat IA mostrará error claro
  // cuando intenten usarlo en lugar de impedir que abra la app.
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] .env no se pudo cargar: $e');
  }

  // Inicializar formato de fechas en es_CO (Colombia).
  await initializeDateFormatting('es_CO', null);

  // Inicializar el servicio de preferencias (nombre del usuario, etc.).
  await PreferencesService.instance.inicializar();

  // Notificaciones locales — silenciar fallas si el dispositivo
  // no las soporta (por ejemplo emuladores antiguos).
  try {
    await NotificationService.inicializar();
    await NotificationService.programarRecordatorioDiario();
  } catch (e) {
    debugPrint('[main] notificaciones no disponibles: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Presupuesto',
      debugShowCheckedModeBanner: false,

      // Localización: necesario para que DatePicker, formato de mes,
      // etc. respeten el locale es_CO.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('es', 'ES'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'CO'),

      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primary,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.black,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  // ===========================
  // CONTROLLERS Y ESTADO
  // ===========================

  // FIX #1: Eliminada lista duplicada 'movimientos' — solo existe _movimientos
  List<Map<String, dynamic>> _movimientos = [];

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _valorController = TextEditingController();
  final TextEditingController _nombreCategoriaController =
      TextEditingController();
  final TextEditingController _emojiCategoriaController =
      TextEditingController();
  final TextEditingController _buscarController = TextEditingController();

  String _filtroTiempo = 'hoy';
  String _filtroTipo = 'todos';
  bool _esFijo = false;
  bool _subiendoBackup = false;

  DateTime? _fechaInicioPersonalizada;
  DateTime? _fechaFinPersonalizada;
  String? _tipoSeleccionado;
  String? _categoriaSeleccionada;
  String _textoBusqueda = '';

  // Vínculo del movimiento con una deuda específica (amortización).
  // Solo se setea cuando la categoría es 'Deuda' y el usuario eligió
  // a qué deuda apuntar.
  int? _deudaIdSeleccionada;
  String? _deudaSeleccionadaNombre;

  // Nombre del usuario para el saludo del header (de PreferencesService).
  String? _nombreUsuario;

  // Cantidad de deudas activas — alimenta el badge del ícono de Deudas.
  // 0 = sin badge, >0 = badge naranja. La severidad (rojo) se cableará
  // cuando integremos el brain en la tanda del gancho psicológico.
  int _deudasActivas = 0;

  // FIX #17: Guardamos el balance anterior para que la animación no arranque desde 0 en cada rebuild
  double _balanceAnterior = 0;

  // FIX #12: NumberFormat como instancia estática para no recrearla en cada llamada
  static final _formatoMoneda = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // ===========================
  // CONSTANTES / CATÁLOGOS
  // ===========================
  List<Map<String, dynamic>> categorias = [];

  // ===========================
  // GETTERS CALCULADOS
  // ===========================
  List<Map<String, dynamic>> get gastosFiltrados =>
      movimientosFiltrados.where((m) => m['tipo'] == 'gasto').toList();

  List<Map<String, dynamic>> get ingresosFiltrados =>
      movimientosFiltrados.where((m) => m['tipo'] == 'ingreso').toList();

  double get totalIngresos =>
      ingresosFiltrados.fold(0.0, (sum, m) => sum + (m['valor'] as num));

  // Total de GASTOS OPERATIVOS — excluye amortizaciones (movimientos con
  // deuda_id) según el MODELO_FINANCIERO.md. También sigue excluyendo
  // el flag viejo `es_deuda` por compatibilidad con datos previos.
  double get totalGastos => gastosFiltrados
      .where((m) => m['es_deuda'] != 1 && m['deuda_id'] == null)
      .fold(0.0, (sum, m) => sum + (m['valor'] as num));

  // Total de AMORTIZACIONES — pagos vinculados a deudas. Se muestran en
  // su propia columna "Deudas" del resumen, separados de los gastos
  // operativos. Incluye los viejos (`es_deuda = 1`) y los nuevos
  // (`deuda_id != null`) para que la transición sea transparente.
  double get totalDeudas => gastosFiltrados
      .where((m) => m['es_deuda'] == 1 || m['deuda_id'] != null)
      .fold(0.0, (sum, m) => sum + (m['valor'] as num));

  double get balance => totalIngresos - totalGastos - totalDeudas;

  // ===========================
  // INSIGHT
  // ===========================
  String _generarInsight() {
    final contexto = _contextoPeriodo();

    if (totalIngresos == 0 && totalGastos == 0 && totalDeudas == 0) {
      return "$contexto aún no registras movimientos";
    }

    if (totalIngresos > 0 && totalGastos == 0 && totalDeudas == 0) {
      return "$contexto no has registrado gastos (${totalIngresos.toStringAsFixed(0)} ingresados)";
    }

    if (totalIngresos == 0 && (totalGastos > 0 || totalDeudas > 0)) {
      return "$contexto tienes gastos sin ingresos registrados";
    }

    // FIX #7: ratio solo sobre gastos operativos (sin deudas)
    final porcentajeGasto = (totalGastos / totalIngresos) * 100;
    final porcentajeAhorro = 100 - porcentajeGasto;

    if (porcentajeAhorro >= 70) {
      return "$contexto estás logrando un ahorro sobresaliente (${porcentajeAhorro.toStringAsFixed(0)}%)";
    }
    if (porcentajeAhorro >= 40) {
      if (_filtroTiempo == 'hoy') {
        return "$contexto vas muy bien con tus gastos (${porcentajeAhorro.toStringAsFixed(0)}%)";
      }
      return "$contexto mantienes una excelente disciplina financiera (${porcentajeAhorro.toStringAsFixed(0)}%)";
    }
    if (porcentajeAhorro >= 20) {
      return "$contexto tienes un buen nivel de ahorro (${porcentajeAhorro.toStringAsFixed(0)}%)";
    }
    if (porcentajeAhorro > 0) {
      return "$contexto tu margen de ahorro es reducido (${porcentajeAhorro.toStringAsFixed(0)}%)";
    }

    return "$contexto estás gastando más de lo que ingresas";
  }

  String _contextoPeriodo() {
    switch (_filtroTiempo) {
      case 'hoy':
        return "Hoy";
      case 'semana':
        return "Esta semana";
      case 'mes':
        return "Este mes";
      case 'anio':
        return "Este año";
      default:
        return "En este periodo";
    }
  }

  // ── Saludo contextual según la hora del día ────────────────
  String _saludoSegunHora() {
    final hora = DateTime.now().hour;
    if (hora < 12) return 'Buen día';
    if (hora < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  IconData _iconoSaludo() {
    final hora = DateTime.now().hour;
    if (hora < 12) return Icons.wb_sunny_outlined; // mañana
    if (hora < 19) return Icons.wb_twilight; // tarde
    return Icons.nightlight_outlined; // noche
  }

  Color _colorIconoSaludo() {
    final hora = DateTime.now().hour;
    if (hora < 19) return const Color(0xFFBA7517); // sol — ámbar
    return AppColors.acento; // luna — acento nocturno
  }

  String _obtenerEmoji(String nombreCategoria) {
    // Caso especial: la categoría "Deuda" vive en código, no en la
    // tabla, así que su emoji se resuelve directo acá.
    if (nombreCategoria == kCategoriaDeuda) return kEmojiCategoriaDeuda;

    final categoriaEncontrada = categorias.firstWhere(
      (cat) => cat['nombre'] == nombreCategoria,
      orElse: () => {},
    );
    return categoriaEncontrada['emoji'] ?? '💰';
  }

  // ===========================
  // FILTROS
  // ===========================
  bool _cumpleFiltroTiempo(DateTime fechaOriginal) {
    final ahora = DateTime.now();
    final fecha = DateTime(
      fechaOriginal.year,
      fechaOriginal.month,
      fechaOriginal.day,
    );
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    if (_filtroTiempo == 'hoy') return fecha == hoy;

    if (_filtroTiempo == 'ayer') {
      return fecha == hoy.subtract(const Duration(days: 1));
    }

    if (_filtroTiempo == 'semana') {
      final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
      final finSemana = inicioSemana.add(const Duration(days: 6));
      return !fecha.isBefore(inicioSemana) && !fecha.isAfter(finSemana);
    }

    if (_filtroTiempo == 'mes') {
      return fecha.year == hoy.year && fecha.month == hoy.month;
    }

    if (_filtroTiempo == 'anio') return fecha.year == hoy.year;

    if (_filtroTiempo == 'personalizado' &&
        _fechaInicioPersonalizada != null &&
        _fechaFinPersonalizada != null) {
      final inicio = DateTime(
        _fechaInicioPersonalizada!.year,
        _fechaInicioPersonalizada!.month,
        _fechaInicioPersonalizada!.day,
      );
      final fin = DateTime(
        _fechaFinPersonalizada!.year,
        _fechaFinPersonalizada!.month,
        _fechaFinPersonalizada!.day,
      );
      return !fecha.isBefore(inicio) && !fecha.isAfter(fin);
    }

    return true;
  }

  List<Map<String, dynamic>> get movimientosFiltrados {
    return _movimientos.where((movimiento) {
      final fecha = DateTime.parse(movimiento['fecha']);
      if (!_cumpleFiltroTiempo(fecha)) return false;
      if (_filtroTipo == 'gasto' && movimiento['tipo'] != 'gasto') return false;
      if (_filtroTipo == 'ingreso' && movimiento['tipo'] != 'ingreso') {
        return false;
      }
      return true;
    }).toList();
  }

  // ===========================
  // CICLO DE VIDA
  // ===========================
  @override
  void initState() {
    super.initState();
    // FIX #9: removidas las doble asignaciones de _filtroTiempo y _filtroTipo
    _cargarCategorias();
    _cargarMovimientos();
    _cargarDeudasActivas();
    _cargarNombreYBienvenida();
  }

  @override
  void dispose() {
    _descController.dispose();
    _valorController.dispose();
    _nombreCategoriaController.dispose();
    _emojiCategoriaController.dispose();
    _buscarController.dispose();
    super.dispose();
  }

  // ===========================
  // MÉTODOS DB / LÓGICA
  // ===========================
  Future<void> _cargarMovimientos() async {
    final data = await DatabaseHelper.instance.obtenerMovimientos();
    setState(() {
      _movimientos = data;
    });
  }

  Future<void> _cargarDeudasActivas() async {
    final deudas = await DatabaseHelper.instance.obtenerDeudas();
    if (!mounted) return;
    setState(() {
      _deudasActivas = deudas.length;
    });
  }

  Future<void> _cargarNombreYBienvenida() async {
    final nombre = PreferencesService.instance.nombreUsuario;
    if (nombre != null) {
      setState(() => _nombreUsuario = nombre);
      return;
    }
    // Primer arranque: no hay nombre. Esperamos a que el primer frame
    // se dibuje y mostramos el diálogo de bienvenida.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarDialogoBienvenida();
    });
  }

  Future<void> _mostrarDialogoBienvenida() async {
    final controller = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¡Bienvenido! 👋'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Para personalizar tu experiencia, ¿cómo te llamás?',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Tu nombre',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Continuar'),
            ),
          ],
        );
      },
    );

    if (nombre != null && nombre.isNotEmpty) {
      await PreferencesService.instance.guardarNombre(nombre);
      if (!mounted) return;
      setState(() => _nombreUsuario = nombre);
    }
  }

  Future<void> _cargarCategorias() async {
    final data = await DatabaseHelper.instance.obtenerCategorias();

    if (data.isEmpty) {
      final categoriasIniciales = [
        {'nombre': 'Alimentación', 'emoji': '🍔'},
        {'nombre': 'Transporte', 'emoji': '🚗'},
        {'nombre': 'Vivienda', 'emoji': '🏠'},
        {'nombre': 'Servicios', 'emoji': '💡'},
        {'nombre': 'Salud', 'emoji': '❤️'},
        {'nombre': 'Educación', 'emoji': '🎓'},
        {'nombre': 'Ocio', 'emoji': '🎮'},
        {'nombre': 'Otros', 'emoji': '📦'},
      ];
      for (var cat in categoriasIniciales) {
        await DatabaseHelper.instance.insertarCategoria(cat);
      }
      final nuevaData = await DatabaseHelper.instance.obtenerCategorias();
      setState(() => categorias = nuevaData);
    } else {
      setState(() => categorias = data);
    }
  }

  Future<void> _ejecutarBackup() async {
    setState(() => _subiendoBackup = true);
    try {
      await ExportHelper.exportarMovimientosLocal();
      final resultado = await GoogleDriveService().uploadCSV();
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resultado)));
      }
    } finally {
      if (mounted) setState(() => _subiendoBackup = false);
    }
  }

  void _abrirMetas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => MetasScreen()),
    );
  }

  void _abrirDeudas() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DeudasScreen()),
    );
  }

  void _abrirDashboard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FinancialDashboardScreen()),
    );
  }

  Future<void> _eliminarMovimiento(int id) async {
    // Si el movimiento tenía un deuda_id vinculado, su eliminación va a
    // devolverle el saldo a esa deuda (el brain recalcula saldos como
    // saldo_inicial − suma de amortizaciones). Avisamos al usuario antes
    // de eso, porque es un cambio que afecta una segunda entidad.
    final movimiento = _movimientos.firstWhere(
      (m) => m['id'] == id,
      orElse: () => {},
    );
    final deudaIdVinculada = movimiento['deuda_id'] as int?;
    String? acreedorVinculado;
    if (deudaIdVinculada != null) {
      final deudas =
          await DatabaseHelper.instance.obtenerTodasLasDeudas();
      final encontrada = deudas.firstWhere(
        (d) => d['id'] == deudaIdVinculada,
        orElse: () => {},
      );
      if (encontrada.isNotEmpty) {
        acreedorVinculado = encontrada['acreedor'] as String?;
      }
    }

    final contenidoDialog = deudaIdVinculada != null
        ? "Este movimiento estaba vinculado a la deuda con "
            "${acreedorVinculado ?? 'tu acreedor'}. Si lo eliminás, "
            "ese monto vuelve a sumarse al saldo de la deuda. ¿Confirmás?"
        : "¿Estás seguro que deseas eliminar este movimiento?";

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar movimiento"),
        content: Text(contenidoDialog),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text("Eliminar", style: TextStyle(color: AppColors.gasto)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DatabaseHelper.instance.eliminarMovimiento(id);
      if (!mounted) return;
      await _cargarMovimientos();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            deudaIdVinculada != null
                ? "Movimiento eliminado · saldo devuelto a la deuda"
                : "Movimiento eliminado",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

 // ===========================
  // BOTTOM SHEET MOVIMIENTO (unificado: crear + editar)
  // ===========================
  //
  // Un solo formulario para ambos casos. Si recibe `existente`, entra en
  // modo edición: pre-carga los datos, cambia el título y el botón, y al
  // guardar hace UPDATE en lugar de INSERT. Si no, es modo creación.
  //
  // La UI (toggle, monto protagonista, selector de categoría, switch fijo,
  // formato de miles) es idéntica en ambos modos — esa es la razón de
  // unificar: un solo diseño que mantener.
  //
  // Cuando la categoría seleccionada es "Deuda" (la especial), el switch
  // "Gasto fijo" se prende solo y queda bloqueado: por contrato del modelo
  // financiero, una amortización siempre es gasto fijo.
  void _mostrarFormularioMovimiento({Map<String, dynamic>? existente}) {
    final bool esEdicion = existente != null;

    // El deuda_id ORIGINAL del movimiento (antes de cualquier edición).
    // Lo necesitamos para detectar al guardar si el usuario rompió el
    // vínculo durante la edición y, en ese caso, pedirle confirmación
    // para eliminar el movimiento (ver MODELO_FINANCIERO.md).
    final int? deudaIdOriginal =
        esEdicion ? existente['deuda_id'] as int? : null;

    // Pre-cargar estado según el modo.
    if (esEdicion) {
      _tipoSeleccionado = existente['tipo'];
      _categoriaSeleccionada = existente['categoria'];
      _valorController.text =
          MilesInputFormatter.format((existente['valor'] as num).toDouble());
      _descController.text = existente['descripcion'] ?? '';
      _esFijo = existente['es_fijo'] == 1;
      _deudaIdSeleccionada = existente['deuda_id'] as int?;
      // El nombre de la deuda lo resolvemos asincrónico abajo si hace falta.
      _deudaSeleccionadaNombre = null;
      if (_deudaIdSeleccionada != null) {
        _resolverNombreDeuda(_deudaIdSeleccionada!);
      }
    } else {
      _descController.clear();
      _valorController.clear();
      _tipoSeleccionado = null;
      _categoriaSeleccionada = null;
      _esFijo = false;
      _deudaIdSeleccionada = null;
      _deudaSeleccionadaNombre = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Color semántico según el tipo elegido (gris si aún no eligió).
            final Color colorTipo = _tipoSeleccionado == 'gasto'
                ? AppColors.gasto
                : _tipoSeleccionado == 'ingreso'
                    ? AppColors.ingreso
                    : Colors.grey;

            final bool esCategoriaDeuda =
                _categoriaSeleccionada == kCategoriaDeuda;

            // Para guardar: si es categoría Deuda exigimos que haya una
            // deuda elegida; sino, la deuda no es válida.
            final bool puedeGuardar = _tipoSeleccionado != null &&
                _categoriaSeleccionada != null &&
                _valorController.text.isNotEmpty &&
                (!esCategoriaDeuda || _deudaIdSeleccionada != null);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      esEdicion ? 'Editar movimiento' : 'Nuevo movimiento',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // ── Toggle Gasto / Ingreso ──
                    Row(
                      children: [
                        Expanded(
                          child: _ToggleTipo(
                            label: 'Gasto',
                            icono: Icons.arrow_circle_down_outlined,
                            color: AppColors.gasto,
                            seleccionado: _tipoSeleccionado == 'gasto',
                            onTap: () => setModalState(() {
                              _tipoSeleccionado = 'gasto';
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _ToggleTipo(
                            label: 'Ingreso',
                            icono: Icons.arrow_circle_up_outlined,
                            color: AppColors.ingreso,
                            seleccionado: _tipoSeleccionado == 'ingreso',
                            onTap: () => setModalState(() {
                              _tipoSeleccionado = 'ingreso';
                              _esFijo = false; // fijo no aplica a ingresos
                              // Cambiar a ingreso limpia cualquier vínculo
                              // con deuda; no tiene sentido.
                              if (_categoriaSeleccionada == kCategoriaDeuda) {
                                _categoriaSeleccionada = null;
                              }
                              _deudaIdSeleccionada = null;
                              _deudaSeleccionadaNombre = null;
                            }),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Monto protagonista ──
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'MONTO',
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              color: Colors.grey.shade500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                '\$ ',
                                style: TextStyle(
                                  fontSize: 26,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _valorController,
                                  autofocus: !esEdicion,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  inputFormatters: [MilesInputFormatter()],
                                  onChanged: (_) => setModalState(() {}),
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w600,
                                    color: colorTipo,
                                    letterSpacing: -0.5,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade300,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            height: 2,
                            width: 180,
                            margin: const EdgeInsets.only(top: 6),
                            color: colorTipo.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Selector de categoría (fila que abre lista) ──
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _abrirSelectorCategoria(setModalState),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            if (_categoriaSeleccionada != null) ...[
                              Text(
                                _obtenerEmoji(_categoriaSeleccionada!),
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _categoriaSeleccionada!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF333333),
                                ),
                              ),
                            ] else
                              Text(
                                'Selecciona categoría',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            const Spacer(),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.grey.shade500,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Fila secundaria: la deuda vinculada ──
                    // Solo aparece cuando la categoría es "Deuda".
                    // Muestra a qué deuda apunta este movimiento y permite
                    // cambiarla con un tap.
                    if (esCategoriaDeuda) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _abrirSelectorDeudas(setModalState),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.deuda.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.deuda.withValues(alpha: 0.20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.credit_card_outlined,
                                size: 18,
                                color: AppColors.deuda,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _deudaSeleccionadaNombre ??
                                      'Selecciona la deuda a pagar',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _deudaSeleccionadaNombre != null
                                        ? const Color(0xFF333333)
                                        : Colors.grey.shade500,
                                    fontWeight: _deudaSeleccionadaNombre != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.keyboard_arrow_down,
                                size: 18,
                                color: Colors.grey.shade500,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    // ── Descripción ──
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _descController,
                        decoration: InputDecoration(
                          hintText: 'Descripción (opcional)',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                          prefixIcon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: Colors.grey.shade500,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                        ),
                      ),
                    ),

                    // ── Switch gasto fijo (solo en gasto) ──
                    // Cuando la categoría es "Deuda", el switch queda
                    // prendido y NO editable: por contrato del modelo, una
                    // amortización es siempre gasto fijo. La etiqueta
                    // cambia para que el usuario entienda el porqué.
                    if (_tipoSeleccionado == 'gasto') ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Gasto fijo',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF333333),
                                  ),
                                ),
                                Text(
                                  esCategoriaDeuda
                                      ? 'Pago de deuda · automático'
                                      : 'Se repite cada mes',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            Switch(
                              value: _esFijo,
                              onChanged: esCategoriaDeuda
                                  ? null
                                  : (v) => setModalState(() => _esFijo = v),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 22),

                    // ── Botón guardar (verde de marca siempre) ──
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: puedeGuardar
                            ? () => _persistirMovimiento(
                                  existente: existente,
                                  deudaIdOriginal: deudaIdOriginal,
                                )
                            : null,
                        child: Text(
                          esEdicion
                              ? 'Guardar cambios'
                              : (_tipoSeleccionado == 'ingreso'
                                  ? 'Guardar ingreso'
                                  : 'Guardar gasto'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Persiste el movimiento: INSERT si es nuevo, UPDATE si trae `existente`.
  //
  // Caso especial — edición que ROMPE el vínculo con una deuda: si el
  // movimiento tenía `deudaIdOriginal` y ahora el `deuda_id` es null o
  // cambió, según el MODELO_FINANCIERO.md el movimiento perdió su razón
  // de ser. La política es eliminarlo, con confirmación explícita al
  // usuario antes.
  Future<void> _persistirMovimiento({
    Map<String, dynamic>? existente,
    int? deudaIdOriginal,
  }) async {
    final valor = MilesInputFormatter.parse(_valorController.text);
    if (valor == null ||
        _tipoSeleccionado == null ||
        _categoriaSeleccionada == null) return;

    // Detección de "vínculo roto" en edición.
    final bool rompioVinculo = existente != null &&
        deudaIdOriginal != null &&
        _deudaIdSeleccionada != deudaIdOriginal;

    if (rompioVinculo) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: const Text('Romper vínculo con la deuda'),
          content: const Text(
            'Este movimiento estaba vinculado a una deuda. '
            'Si confirmás, el movimiento se elimina y el saldo vuelve '
            'a esa deuda. ¿Confirmás?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                'Eliminar',
                style: TextStyle(color: AppColors.gasto),
              ),
            ),
          ],
        ),
      );

      if (confirmar != true) return; // cancelado: no hago nada.

      // Confirmado: elimino el movimiento. El saldo de la deuda se
      // recompondrá solo cuando el motor pase a calcular saldos desde
      // movimientos (Paso 5). Por ahora basta con eliminar.
      await DatabaseHelper.instance
          .eliminarMovimiento(existente['id'] as int);
      if (!mounted) return;
      Navigator.pop(context);
      await _cargarMovimientos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Movimiento eliminado · saldo devuelto a la deuda'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final datos = {
      'tipo': _tipoSeleccionado,
      'categoria': _categoriaSeleccionada,
      'descripcion': _descController.text,
      'valor': valor,
      'es_fijo': _esFijo ? 1 : 0,
      // Flag viejo del modelo anterior: lo dejamos en 0 para los
      // movimientos nuevos. Los pagos de deuda se distinguen ahora por
      // `deuda_id`, no por este flag. Ver MODELO_FINANCIERO.md.
      'es_deuda': 0,
      'acreedor': null,
      'deuda_id': _deudaIdSeleccionada,
    };

    // Detección de "saldé esta deuda": si el movimiento es una amortización
    // y el saldo posterior llega a 0 o menos, vamos a disparar la pantalla
    // de celebración full-screen una vez guardado el movimiento. La misma
    // lógica vive también en _registrarAbono de DeudasScreen — la decisión
    // del modelo es que el momento "saldé" no depende de la puerta de
    // entrada (formulario principal o botón "Abonar al capital").
    String? acreedorSaldado;
    double? montoSaldado;
    bool eraLaUltimaDeuda = false;
    if (_deudaIdSeleccionada != null && existente == null) {
      // Calcular saldo previo: saldo_inicial − suma de amortizaciones ya
      // registradas para esta deuda (todavía sin el movimiento nuevo).
      final deudasTodas =
          await DatabaseHelper.instance.obtenerTodasLasDeudas();
      final deudaTarget = deudasTodas.firstWhere(
        (d) => d['id'] == _deudaIdSeleccionada,
        orElse: () => {},
      );
      if (deudaTarget.isNotEmpty) {
        final saldoInicial =
            (deudaTarget['saldo_inicial'] as num).toDouble();
        final movsTodos =
            await DatabaseHelper.instance.obtenerMovimientos();
        final pagosPrevios = movsTodos
            .where((m) => m['deuda_id'] == _deudaIdSeleccionada)
            .fold(
              0.0,
              (s, m) => s + (m['valor'] as num).toDouble(),
            );
        final saldoPrevio = saldoInicial - pagosPrevios;

        // ── NIVEL 2: red de seguridad ──
        // Si el saldo previo ya es <= 0, la deuda YA estaba saldada y la
        // app no debería haber permitido llegar acá (el selector filtra
        // saldadas). Si igual ocurre — race condition, edición de un
        // movimiento viejo —, rechazamos el guardado y avisamos breve.
        // Sin diálogo: el usuario no causó esto, no le pedimos decisión.
        if (saldoPrevio <= 0) {
          if (!mounted) return;
          final acreedor =
              deudaTarget['acreedor'] as String? ?? 'esa deuda';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La deuda con $acreedor ya está saldada. '
                'No se guardó el movimiento.',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        // Saldo previo > 0: chequear si este movimiento la saldará.
        final saldoPosterior = saldoPrevio - valor;
        if (saldoPosterior <= 0) {
          acreedorSaldado = deudaTarget['acreedor'] as String?;
          montoSaldado = saldoInicial;
          // ¿Quedan otras deudas activas? Si todas las demás ya están
          // saldadas (saldo recalculado <= 0), esta era la última.
          final otras = deudasTodas
              .where((d) => d['id'] != _deudaIdSeleccionada)
              .toList();
          eraLaUltimaDeuda = otras.every((d) {
            final si = (d['saldo_inicial'] as num).toDouble();
            final pagosOtra = movsTodos
                .where((m) => m['deuda_id'] == d['id'])
                .fold(0.0, (s, m) => s + (m['valor'] as num).toDouble());
            return (si - pagosOtra) <= 0;
          });
        }
      }
    }

    if (existente != null) {
      // UPDATE: preservamos id y la fecha original.
      await DatabaseHelper.instance.actualizarMovimiento({
        'id': existente['id'],
        ...datos,
      });
    } else {
      // INSERT: fecha = ahora.
      await DatabaseHelper.instance.insertarMovimiento({
        ...datos,
        'fecha': DateTime.now().toIso8601String(),
      });
    }

    if (!mounted) return;
    Navigator.pop(context);
    await _cargarMovimientos();
    await _cargarDeudasActivas(); // por si una deuda saldó, actualizamos el badge.

    // Si este movimiento saldó una deuda, mostramos la celebración antes
    // del snackbar. La pantalla se cierra con un tap del usuario y vuelve
    // acá a continuar el flujo normal.
    if (acreedorSaldado != null && montoSaldado != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CelebracionDeudaScreen(
            acreedor: acreedorSaldado!,
            montoSaldado: montoSaldado!,
            esLaUltimaDeuda: eraLaUltimaDeuda,
          ),
          fullscreenDialog: true,
        ),
      );
      if (!mounted) return;
      return; // ya celebramos; no mostrar el snackbar regular.
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          existente != null
              ? 'Movimiento actualizado ✅'
              : 'Movimiento guardado ✅',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Selector de categoría como bottom sheet secundario.
  //
  // Si hay deudas activas y el tipo es "gasto", la categoría especial
  // "Deuda" aparece arriba del todo, destacada visualmente. Al elegirla
  // se cierra este sheet y se abre el de selección de deuda; el resto
  // del flujo lo maneja `_abrirSelectorDeudas`.
  void _abrirSelectorCategoria(StateSetter setModalState) {
    final bool mostrarCategoriaDeuda =
        _tipoSeleccionado == 'gasto' && _deudasActivas > 0;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Selecciona categoría',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // Categoría especial "Deuda" — solo cuando aplica.
                    if (mostrarCategoriaDeuda)
                      _ItemCategoriaDeuda(
                        seleccionada:
                            _categoriaSeleccionada == kCategoriaDeuda,
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          // Abrimos el selector de deudas; ese se encarga
                          // de setear la categoría y la deuda elegida.
                          _abrirSelectorDeudas(setModalState);
                        },
                      ),
                    if (mostrarCategoriaDeuda)
                      const Divider(height: 1, indent: 16, endIndent: 16),

                    // Resto de categorías normales.
                    ...categorias.map((cat) {
                      final seleccionada =
                          _categoriaSeleccionada == cat['nombre'];
                      return ListTile(
                        leading: Text(
                          cat['emoji'],
                          style: const TextStyle(fontSize: 22),
                        ),
                        title: Text(cat['nombre']),
                        trailing: seleccionada
                            ? Icon(Icons.check,
                                color: AppColors.primary, size: 20)
                            : null,
                        onTap: () {
                          // Cambiar a una categoría normal limpia el
                          // vínculo a deuda (la categoría dejó de ser
                          // "Deuda" y el switch fijo vuelve a ser
                          // editable la próxima vez que se evalúe).
                          setModalState(() {
                            _categoriaSeleccionada = cat['nombre'];
                            _deudaIdSeleccionada = null;
                            _deudaSeleccionadaNombre = null;
                          });
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Selector de deuda — lista de deudas activas para vincular el pago.
  // Si el usuario elige una, la categoría se setea a "Deuda" y el switch
  // "Gasto fijo" se prende automáticamente.
  //
  // Filtra defensivamente por SALDO RECONCILIADO (no por el flag `activa`
  // de la tabla, que puede estar desactualizado): solo aparecen deudas
  // cuyo saldo_inicial − suma de amortizaciones es mayor a cero. Así no
  // se puede vincular un pago a una deuda ya saldada por error.
  Future<void> _abrirSelectorDeudas(StateSetter setModalState) async {
    final deudasCrudas = await DatabaseHelper.instance.obtenerDeudas();
    final movimientosTodos =
        await DatabaseHelper.instance.obtenerMovimientos();

    // Pre-acumular pagos por deuda_id en una sola pasada.
    final pagosPorDeuda = <int, double>{};
    for (final m in movimientosTodos) {
      final did = m['deuda_id'] as int?;
      if (did == null) continue;
      pagosPorDeuda[did] =
          (pagosPorDeuda[did] ?? 0) + (m['valor'] as num).toDouble();
    }

    // Reconciliar y filtrar: solo deudas con saldo real > 0.
    final deudas = deudasCrudas.where((d) {
      final saldoInicial = (d['saldo_inicial'] as num).toDouble();
      final pagado = pagosPorDeuda[d['id'] as int] ?? 0;
      return (saldoInicial - pagado) > 0;
    }).map((d) {
      // Devolvemos el mapa con saldo_actual reconciliado, para que la UI
      // muestre el saldo real y no el de la tabla.
      final saldoInicial = (d['saldo_inicial'] as num).toDouble();
      final pagado = pagosPorDeuda[d['id'] as int] ?? 0;
      return {
        ...d,
        'saldo_actual':
            (saldoInicial - pagado).clamp(0.0, saldoInicial),
      };
    }).toList();

    if (!mounted) return;

    if (deudas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tenés deudas activas para vincular.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '¿A qué deuda va este pago?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: deudas.length,
                  itemBuilder: (context, index) {
                    final d = deudas[index];
                    final acreedor = d['acreedor'] as String;
                    final saldo = (d['saldo_actual'] as num).toDouble();
                    final id = d['id'] as int;
                    final seleccionada = _deudaIdSeleccionada == id;

                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.deuda.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.credit_card_outlined,
                          color: AppColors.deuda,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        acreedor,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        'Saldo ${_formatoMoneda.format(saldo)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      trailing: seleccionada
                          ? Icon(Icons.check,
                              color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        setModalState(() {
                          _categoriaSeleccionada = kCategoriaDeuda;
                          _deudaIdSeleccionada = id;
                          _deudaSeleccionadaNombre = acreedor;
                          _esFijo = true; // amortización = gasto fijo.
                        });
                        Navigator.of(sheetContext).pop();
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // Resuelve el nombre del acreedor a partir del deuda_id. Se llama una
  // sola vez al abrir el formulario en modo edición si el movimiento
  // tenía un vínculo a deuda.
  Future<void> _resolverNombreDeuda(int deudaId) async {
    final deudas = await DatabaseHelper.instance.obtenerTodasLasDeudas();
    final encontrada = deudas.firstWhere(
      (d) => d['id'] == deudaId,
      orElse: () => {},
    );
    if (!mounted) return;
    if (encontrada.isNotEmpty) {
      setState(() {
        _deudaSeleccionadaNombre = encontrada['acreedor'] as String?;
      });
    }
  }

  // ===========================
  // GESTIÓN DE CATEGORÍAS
  // ===========================
  void _mostrarGestionCategorias() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Gestionar Categorías',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 200,
                    child: categorias.isEmpty
                        ? const Center(
                            child: Text(
                              'No hay categorías aún.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: categorias.length,
                            itemBuilder: (context, index) {
                              final cat = categorias[index];
                              return ListTile(
                                leading: Text(
                                  cat['emoji'],
                                  style: const TextStyle(fontSize: 22),
                                ),
                                title: Text(cat['nombre']),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    await DatabaseHelper.instance
                                        .eliminarCategoria(cat['id'] as int);
                                    await _cargarCategorias();
                                    if (!mounted) return;
                                    setModalState(() {});
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),

                  const Divider(height: 24),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Nueva categoría',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _nombreCategoriaController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la categoría',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _emojiCategoriaController,
                    decoration: const InputDecoration(
                      labelText: 'Emoji',
                      prefixIcon: Icon(Icons.emoji_emotions_outlined),
                      hintText: '🍔',
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save),
                      label: const Text('Guardar categoría'),
                      onPressed: () async {
                        if (_nombreCategoriaController.text.isEmpty ||
                            _emojiCategoriaController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Completa el nombre y el emoji.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        // Bloquear que el usuario intente crear una
                        // categoría llamada "Deuda" — ya existe como
                        // especial y vive en código.
                        if (_nombreCategoriaController.text.trim() ==
                            kCategoriaDeuda) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'La categoría "Deuda" es del sistema y no se puede duplicar.',
                              ),
                              duration: Duration(seconds: 3),
                            ),
                          );
                          return;
                        }

                        await DatabaseHelper.instance.insertarCategoria({
                          'nombre': _nombreCategoriaController.text,
                          'emoji': _emojiCategoriaController.text,
                        });

                        _nombreCategoriaController.clear();
                        _emojiCategoriaController.clear();

                        await _cargarCategorias();
                        if (!mounted) return;
                        setModalState(() {});
                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Categoría guardada ✅'),
                            duration: Duration(seconds: 2),
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
      },
    );
  }

  // ===========================
  // SELECTOR DE PERIODO
  // FIX #10: una sola implementación unificada del selector
  // ===========================
  void _mostrarSelectorPeriodo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _itemPeriodo("Hoy", "hoy"),
              _itemPeriodo("Ayer", "ayer"),
              _itemPeriodo("Semana", "semana"),
              _itemPeriodo("Mes", "mes"),
              _itemPeriodo("Año", "anio"),
              _itemPeriodo("Personalizado", "personalizado"),
            ],
          ),
        );
      },
    );
  }

  Widget _itemPeriodo(String texto, String valor) {
    final seleccionado = _filtroTiempo == valor;

    return ListTile(
      title: Text(
        texto,
        style: TextStyle(
          fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: seleccionado ? const Icon(Icons.check, size: 18) : null,
      onTap: () async {
        Navigator.pop(context);

        if (valor == "personalizado") {
          final rango = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange:
                _fechaInicioPersonalizada != null &&
                    _fechaFinPersonalizada != null
                ? DateTimeRange(
                    start: _fechaInicioPersonalizada!,
                    end: _fechaFinPersonalizada!,
                  )
                : null,
          );

          if (rango != null) {
            setState(() {
              _fechaInicioPersonalizada = rango.start;
              _fechaFinPersonalizada = rango.end;
              _filtroTiempo = "personalizado";
            });
          }
        } else {
          setState(() => _filtroTiempo = valor);
        }
      },
    );
  }

  // ===========================
  // LISTA DE MOVIMIENTOS
  // ===========================
  Widget _listaMovimientos(List<Map<String, dynamic>> lista) {
    // FIX #6: el buscador ahora también busca por acreedor
    final listaFiltrada = _textoBusqueda.isEmpty
        ? lista
        : lista.where((m) {
            final desc = (m['descripcion'] ?? '').toString().toLowerCase();
            final cat = (m['categoria'] ?? '').toString().toLowerCase();
            final acreedor = (m['acreedor'] ?? '').toString().toLowerCase();
            final busqueda = _textoBusqueda.toLowerCase();
            return desc.contains(busqueda) ||
                cat.contains(busqueda) ||
                acreedor.contains(busqueda);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _buscarController,
            decoration: InputDecoration(
              hintText: 'Buscar por categoría, descripción o acreedor...',
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _textoBusqueda.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _buscarController.clear();
                          _textoBusqueda = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
            ),
            onChanged: (valor) => setState(() => _textoBusqueda = valor),
          ),
        ),

        Expanded(
          child: listaFiltrada.isEmpty
              ? _buildEstadoVacio()
              // FIX #3: pre-calcular la lista con headers una sola vez fuera del builder
              : _buildListaAgrupada(listaFiltrada),
        ),
      ],
    );
  }

  // FIX #3: lista pre-calculada una sola vez, no en cada frame
  Widget _buildListaAgrupada(List<Map<String, dynamic>> lista) {
    // Construir la lista con headers una sola vez
    final List<dynamic> items = [];
    String? grupoActual;

    for (var m in lista) {
      final fecha = DateTime.parse(m['fecha']);
      final etiqueta = _etiquetaFecha(fecha);
      if (etiqueta != grupoActual) {
        items.add(etiqueta);
        grupoActual = etiqueta;
      }
      items.add(m);
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              item,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          );
        }

        return _buildMovimientoCard(item as Map<String, dynamic>);
      },
    );
  }

  Widget _buildEstadoVacio() {
    final hayBusqueda = _textoBusqueda.isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(hayBusqueda ? '🔍' : '📭', style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(
            hayBusqueda
                ? 'Sin resultados para "$_textoBusqueda"'
                : 'No hay movimientos aquí',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hayBusqueda
                ? 'Intenta con otra palabra'
                : 'Toca el botón + para agregar\ntu primer movimiento',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  String _etiquetaFecha(DateTime fecha) {
    final hoy = DateTime.now();
    final ayer = hoy.subtract(const Duration(days: 1));

    if (fecha.year == hoy.year &&
        fecha.month == hoy.month &&
        fecha.day == hoy.day) return 'Hoy';

    if (fecha.year == ayer.year &&
        fecha.month == ayer.month &&
        fecha.day == ayer.day) return 'Ayer';

    final diferenciaDias = hoy.difference(fecha).inDays;
    if (diferenciaDias < 7) return 'Esta semana';
    if (diferenciaDias < 30) return 'Este mes';

    return DateFormat('MMMM y', 'es').format(fecha);
  }

  Widget _buildMovimientoCard(Map<String, dynamic> m) {
    return Dismissible(
      key: Key(m['id'].toString()),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.fondo,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            Icon(Icons.edit, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Editar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.gasto,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _mostrarFormularioMovimiento(existente: m);
          return false;
        }
        if (direction == DismissDirection.endToStart) {
          await _eliminarMovimiento(m['id']);
          return false;
        }
        return false;
      },
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Builder(
            builder: (context) {
              final double valor = (m['valor'] is num)
                  ? (m['valor'] as num).toDouble()
                  : 0.0;
              final bool esIngreso = m['tipo'] == 'ingreso';
              final color = esIngreso ? AppColors.ingreso : AppColors.gasto;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _obtenerEmoji(m['categoria']),
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          m['categoria'] ?? '',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((m['descripcion'] ?? '').toString().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              m['descripcion'],
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (m['es_deuda'] == 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.warning_amber,
                                  size: 11,
                                  color: Colors.orange[700],
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  "Deuda con ${m['acreedor'] ?? ''}",
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        "${esIngreso ? '+' : '-'}${_formatearMonto(valor)}",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (m['es_fijo'] == 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Fijo',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (m['es_deuda'] == 1)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.deuda.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Deuda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.deuda,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ===========================
  // RESUMEN FINANCIERO
  // ===========================
  // ── Header de saludo ───────────────────────────────────────
  Widget _buildSaludo() {
    final saludo = _saludoSegunHora();
    final nombre = _nombreUsuario;
    final textoSaludo = nombre != null ? '$saludo, $nombre' : saludo;

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Text(
            textoSaludo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 7),
          Icon(_iconoSaludo(), size: 18, color: _colorIconoSaludo()),
        ],
      ),
    );
  }

  Widget _resumenFinanciero() {
    String periodoTexto = '';
    if (_filtroTiempo == 'hoy') periodoTexto = 'Hoy';
    if (_filtroTiempo == 'ayer') periodoTexto = 'Ayer';
    if (_filtroTiempo == 'semana') periodoTexto = 'Esta semana';
    if (_filtroTiempo == 'mes') periodoTexto = 'Este mes';
    if (_filtroTiempo == 'anio') periodoTexto = 'Este año';
    if (_filtroTiempo == 'personalizado' &&
        _fechaInicioPersonalizada != null &&
        _fechaFinPersonalizada != null) {
      periodoTexto =
          '${_fechaInicioPersonalizada!.day}/${_fechaInicioPersonalizada!.month}'
          ' - '
          '${_fechaFinPersonalizada!.day}/${_fechaFinPersonalizada!.month}';
    }

    // FIX #8: ratio solo sobre gastos operativos, sin deudas
    double ratioGasto = totalIngresos == 0
        ? 0
        : (totalGastos / totalIngresos).clamp(0.0, 1.0).toDouble();

    Color colorBarra = ratioGasto < 0.6
        ? AppColors.ingreso
        : ratioGasto < 0.8
        ? AppColors.deuda
        : AppColors.gasto;

    Color balanceColor = balance > 0.01
        ? AppColors.balancePositivo
        : balance < -0.01
        ? AppColors.balanceNegativo
        : Colors.grey.shade800;

    // FIX #17: animación parte del balance anterior, no desde 0
    final balanceActual = balance;
    final balanceInicio = _balanceAnterior;

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Periodo activo
          GestureDetector(
            onTap: _mostrarSelectorPeriodo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    periodoTexto,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // FIX #17: TweenAnimationBuilder parte del valor anterior
          TweenAnimationBuilder<double>(
            key: ValueKey(balanceActual),
            tween: Tween<double>(begin: balanceInicio, end: balanceActual),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            onEnd: () => _balanceAnterior = balanceActual,
            builder: (context, value, child) {
              return Text(
                _formatearCompacto(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: balanceColor,
                  letterSpacing: 0.5,
                ),
              );
            },
          ),

          const SizedBox(height: 2),

          Text(
            balance > 0.01
                ? 'Balance positivo'
                : balance < -0.01
                ? 'Balance negativo'
                : 'Balance equilibrado',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),

          const SizedBox(height: 4),

          Text(
            _generarInsight(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 16),

          // Barra de presupuesto
          if (totalIngresos > 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Presupuesto usado',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
                Text(
                  '${(ratioGasto * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: colorBarra,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: ratioGasto),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: colorBarra.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(colorBarra),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Ingresos, Gastos y Deudas
          Row(
            children: [
              Expanded(
                child: _datoConTendencia(
                  'Ingresos',
                  totalIngresos,
                  AppColors.ingreso,
                  Icons.arrow_upward,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.grey.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _datoConTendencia(
                  'Gastos',
                  totalGastos,
                  AppColors.gasto,
                  Icons.arrow_downward,
                ),
              ),
              if (totalDeudas > 0) ...[
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.grey.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _datoConTendencia(
                    'Deudas',
                    totalDeudas,
                    AppColors.deuda,
                    Icons.warning_amber_outlined,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _datoConTendencia(
    String titulo,
    double valor,
    Color color,
    IconData icono,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          titulo.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              _formatearCompacto(valor),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===========================
  // BUILD PRINCIPAL
  // ===========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 56,
        title: const Text('Mi Presupuesto'),
        actions: [
          // Dashboard — acción principal.
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: _abrirDashboard,
            tooltip: 'Dashboard',
          ),
          // Deudas — con badge de estado (debt-first design).
          // Sin deudas: ícono limpio. Con deudas: punto naranja.
          // (La severidad roja se cableará con el brain más adelante.)
          IconButton(
            icon: Badge(
              isLabelVisible: _deudasActivas > 0,
              backgroundColor: AppColors.deuda,
              smallSize: 8,
              child: const Icon(Icons.credit_card_outlined),
            ),
            onPressed: _abrirDeudas,
            tooltip: 'Deudas',
          ),
          // Overflow — acciones secundarias (metas, categorías, backup).
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Más opciones',
            onSelected: (valor) {
              switch (valor) {
                case 'metas':
                  _abrirMetas();
                  break;
                case 'categorias':
                  _mostrarGestionCategorias();
                  break;
                case 'backup':
                  if (!_subiendoBackup) _ejecutarBackup();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'metas',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Metas'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'categorias',
                child: Row(
                  children: [
                    Icon(Icons.category_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Categorías'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    _subiendoBackup
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined, size: 20),
                    const SizedBox(width: 12),
                    Text(_subiendoBackup ? 'Subiendo...' : 'Backup'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: Column(
        children: [
          _buildSaludo(),
          _resumenFinanciero(),
          const Divider(height: 1),
          Expanded(child: _listaMovimientos(movimientosFiltrados)),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioMovimiento(),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // FIX #12: usa la instancia estática _formatoMoneda
  String _formatearMonto(double valor) => _formatoMoneda.format(valor);

  // Formato compacto para el resumen (balance y stats): K para miles,
  // M para millones con un decimal. La lista de movimientos sigue usando
  // _formatearMonto (valor completo) — acá solo se busca limpieza visual.
  String _formatearCompacto(double valor) {
    final abs = valor.abs();
    final signo = valor < 0 ? '-' : '';

    if (abs >= 1000000) {
      // Millones con un decimal: 1.200.000 -> "1,2 M". Quitamos el ",0"
      // cuando es redondo (2.000.000 -> "2 M", no "2,0 M").
      final millones = abs / 1000000;
      final texto = millones
          .toStringAsFixed(1)
          .replaceAll('.', ',')
          .replaceAll(',0', '');
      return '$signo\$ $texto M';
    }

    if (abs >= 10000) {
      // Miles a partir de 10.000: 45.000 -> "45 K".
      final miles = (abs / 1000).round();
      return '$signo\$ $miles K';
    }

    // Menos de 10.000: valor completo con separadores ("8.500").
    return _formatoMoneda.format(valor);
  }
}

// ===========================
// LOADING ICON ANIMADO
// ===========================
class _PremiumLoadingIcon extends StatefulWidget {
  const _PremiumLoadingIcon();

  @override
  State<_PremiumLoadingIcon> createState() => _PremiumLoadingIconState();
}

class _PremiumLoadingIconState extends State<_PremiumLoadingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _scale = Tween(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacity = Tween(begin: 0.18, end: 0.30).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      key: const ValueKey("loading"),
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 163, 142, 142)
                  .withValues(alpha: _opacity.value),
              shape: BoxShape.circle,
            ),
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ===========================
// TOGGLE DE TIPO (Gasto / Ingreso) — usado en el formulario
// ===========================
class _ToggleTipo extends StatelessWidget {
  final String label;
  final IconData icono;
  final Color color;
  final bool seleccionado;
  final VoidCallback onTap;

  const _ToggleTipo({
    required this.label,
    required this.icono,
    required this.color,
    required this.seleccionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: seleccionado
              ? color.withValues(alpha: 0.10)
              : const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: seleccionado ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icono,
              size: 22,
              color: seleccionado ? color : Colors.grey.shade400,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: seleccionado ? color : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================
// ITEM DE CATEGORÍA "DEUDA" — destacado, va arriba en el selector
// ===========================
class _ItemCategoriaDeuda extends StatelessWidget {
  final bool seleccionada;
  final VoidCallback onTap;

  const _ItemCategoriaDeuda({
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.deuda.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.deuda.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    kEmojiCategoriaDeuda,
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deuda',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Pago de cuota a una deuda activa',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (seleccionada)
                Icon(Icons.check, color: AppColors.primary, size: 20)
              else
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
