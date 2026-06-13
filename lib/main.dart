import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_colors.dart';
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

  // FIX #7 y #8: totalGastos excluye deudas para no inflar el ratio y el insight
  double get totalGastos => gastosFiltrados
      .where((m) => m['es_deuda'] != 1)
      .fold(0.0, (sum, m) => sum + (m['valor'] as num));

  double get totalDeudas => gastosFiltrados
      .where((m) => m['es_deuda'] == 1)
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

  String _obtenerEmoji(String nombreCategoria) {
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

  // ===========================
  // GUARDAR MOVIMIENTO
  // ===========================
  Future<void> _guardarMovimiento() async {
    final valor = double.tryParse(_valorController.text);
    if (valor == null ||
        _tipoSeleccionado == null ||
        _categoriaSeleccionada == null) return;

    await DatabaseHelper.instance.insertarMovimiento({
      'tipo': _tipoSeleccionado,
      'categoria': _categoriaSeleccionada,
      'descripcion': _descController.text,
      'valor': valor,
      'fecha': DateTime.now().toIso8601String(),
      'es_fijo': _esFijo ? 1 : 0,
      'es_deuda': 0,
      'acreedor': null,
    });

    if (!mounted) return;

    await _cargarMovimientos();

    setState(() {
      _descController.clear();
      _valorController.clear();
      _tipoSeleccionado = null;
      _categoriaSeleccionada = null;
      _esFijo = false;
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Movimiento guardado ✅'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _eliminarMovimiento(int id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar movimiento"),
        content: const Text(
          "¿Estás seguro que deseas eliminar este movimiento?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await DatabaseHelper.instance.eliminarMovimiento(id);
      if (!mounted) return;
      await _cargarMovimientos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Movimiento eliminado"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ===========================
  // EDITAR MOVIMIENTO
  // ===========================
  void _editarMovimiento(Map<String, dynamic> m) {
    setState(() {
      _tipoSeleccionado = m['tipo'];
      _categoriaSeleccionada = m['categoria'];
      _valorController.text = m['valor'].toString();
      _descController.text = m['descripcion'] ?? '';
      _esFijo = m['es_fijo'] == 1;
    });

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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Editar movimiento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      initialValue: _tipoSeleccionado,
                      hint: const Text('Selecciona tipo'),
                      items: const [
                        DropdownMenuItem(value: 'gasto', child: Text('Gasto')),
                        DropdownMenuItem(
                          value: 'ingreso',
                          child: Text('Ingreso'),
                        ),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          _tipoSeleccionado = v;
                          if (v != 'gasto') _esFijo = false;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (_tipoSeleccionado == 'gasto') ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Es gasto fijo'),
                        subtitle: const Text(
                          'Si no es fijo, se considera variable',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _esFijo,
                        onChanged: (value) {
                          setModalState(() => _esFijo = value);
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _categoriaSeleccionada,
                      hint: const Text('Selecciona categoría'),
                      items: categorias.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['nombre'],
                          child: Text('${c['emoji']} ${c['nombre']}'),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setModalState(() => _categoriaSeleccionada = v),
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _valorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar cambios'),
                        onPressed: () async {
                          final valor =
                              double.tryParse(_valorController.text);
                          if (valor == null ||
                              _tipoSeleccionado == null ||
                              _categoriaSeleccionada == null) return;

                          await DatabaseHelper.instance.actualizarMovimiento({
                            'id': m['id'],
                            'tipo': _tipoSeleccionado,
                            'categoria': _categoriaSeleccionada,
                            'descripcion': _descController.text,
                            'valor': valor,
                            'es_fijo': _esFijo ? 1 : 0,
                            'es_deuda': 0,
                            'acreedor': null,
                          });

                          if (!mounted) return;
                          Navigator.pop(context);
                          await _cargarMovimientos();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Movimiento actualizado ✅'),
                              duration: Duration(seconds: 2),
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
      },
    );
  }

  // ===========================
  // BOTTOM SHEET NUEVO MOVIMIENTO
  // ===========================

  void _mostrarFormulario() {
    _descController.clear();
    _valorController.clear();
    _tipoSeleccionado = null;
    _categoriaSeleccionada = null;
    _esFijo = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Nuevo movimiento',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      hint: const Text('Selecciona tipo'),
                      items: const [
                        DropdownMenuItem(value: 'gasto', child: Text('Gasto')),
                        DropdownMenuItem(
                          value: 'ingreso',
                          child: Text('Ingreso'),
                        ),
                      ],
                      onChanged: (v) {
                        setModalState(() {
                          _tipoSeleccionado = v;
                        });
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    if (_tipoSeleccionado == 'gasto') ...[
                      const SizedBox(height: 8),
                      SwitchListTile(
                        title: const Text('Es gasto fijo'),
                        subtitle: const Text(
                          'Si no es fijo, se considera variable',
                          style: TextStyle(fontSize: 11),
                        ),
                        value: _esFijo,
                        onChanged: (value) {
                          setModalState(() => _esFijo = value);
                        },
                      ),
                    ],

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      initialValue: _categoriaSeleccionada,
                      hint: const Text('Selecciona categoría'),
                      items: categorias.map((c) {
                        return DropdownMenuItem<String>(
                          value: c['nombre'],
                          child: Text('${c['emoji']} ${c['nombre']}'),
                        );
                      }).toList(),
                      onChanged: (v) =>
                          setModalState(() => _categoriaSeleccionada = v),
                      decoration: const InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _valorController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Valor',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar movimiento'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _tipoSeleccionado == null
                              ? Colors.grey
                              : (_tipoSeleccionado == 'gasto'
                                    ? Colors.red
                                    : Colors.green),
                        ),
                        onPressed:
                            (_tipoSeleccionado == null ||
                                _categoriaSeleccionada == null ||
                                _valorController.text.isEmpty)
                            ? null
                            : _guardarMovimiento,
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
          color: Colors.blue,
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
          color: Colors.red,
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
          _editarMovimiento(m);
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
              final color = esIngreso ? Colors.green : Colors.red;

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
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Deuda',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
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
        ? Colors.green
        : ratioGasto < 0.8
        ? Colors.orange
        : Colors.red;

    Color balanceColor = balance > 0.01
        ? const Color(0xFF1B5E20)
        : balance < -0.01
        ? const Color(0xFFB71C1C)
        : Colors.grey.shade800;

    // FIX #17: animación parte del balance anterior, no desde 0
    final balanceActual = balance;
    final balanceInicio = _balanceAnterior;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
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
                _formatearMonto(value),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
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
                  Colors.green,
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
                  Colors.red,
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
                    Colors.orange,
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
              _formatearMonto(valor),
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
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 56,
        title: const Text('Mi Presupuesto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            onPressed: _abrirMetas,
            tooltip: 'Metas',
          ),
          IconButton(
            icon: const Icon(Icons.credit_card_outlined),
            onPressed: _abrirDeudas,
            tooltip: 'Deudas',
          ),
          IconButton(
            icon: const Icon(Icons.dashboard_outlined),
            onPressed: _abrirDashboard,
            tooltip: 'Dashboard',
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            onPressed: _mostrarGestionCategorias,
            tooltip: 'Categorías',
          ),
          IconButton(
            splashRadius: 20,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _subiendoBackup
                  ? const _PremiumLoadingIcon()
                  : const Icon(
                      Icons.cloud_upload_outlined,
                      key: ValueKey("icon"),
                    ),
            ),
            onPressed: _subiendoBackup ? null : _ejecutarBackup,
            tooltip: 'Backup',
          ),
        ],
      ),

      body: Column(
        children: [
          _resumenFinanciero(),
          const Divider(height: 1),
          Expanded(child: _listaMovimientos(movimientosFiltrados)),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormulario,
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  // FIX #12: usa la instancia estática _formatoMoneda
  String _formatearMonto(double valor) => _formatoMoneda.format(valor);
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
