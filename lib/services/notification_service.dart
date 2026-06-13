import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'master_financial_brain.dart';
import 'meta_inteligente_engine.dart';
import '../db/database_helper.dart';
import '../models/meta_ahorro.dart';

/// NotificationService — orquesta notificaciones financieras inteligentes.
///
/// Esta versión consume `MasterFinancialBrain` como única fuente de análisis.
/// El cálculo de "cambio de gastos mes a mes" se hace localmente con dos
/// llamadas a la DB porque ese dato puntual no vive en `MasterFinancialResult`
/// (es específico a esta notificación, no aporta exponerlo en el brain).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  // IDs de notificaciones — fijos para evitar duplicados
  static const int _idPresupuesto = 1;
  static const int _idSinRegistros = 2;
  static const int _idMeta = 3;
  static const int _idGastos = 4;
  static const int _idRecordatorio = 5;
  static const int _idMetaVencida = 6;

  // ── Inicializar ───────────────────────────────────────────
  static Future<bool> inicializar() async {
    if (_inicializado) return true;

    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestNotificationsPermission();

    _inicializado = true;
    return true;
  }

  // ── Mostrar notificación simple ───────────────────────────
  static Future<void> _mostrar({
    required int id,
    required String titulo,
    required String cuerpo,
    Importance importancia = Importance.defaultImportance,
    Priority prioridad = Priority.defaultPriority,
  }) async {
    if (!_inicializado) {
      final ok = await inicializar();
      if (!ok) return;
    }

    final detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'mi_presupuesto_channel',
        'Mi Presupuesto',
        channelDescription: 'Notificaciones financieras inteligentes',
        importance: importancia,
        priority: prioridad,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.show(id, titulo, cuerpo, detalles);
  }

  // ── Programar recordatorio diario ─────────────────────────
  static Future<void> programarRecordatorioDiario() async {
    await inicializar();
    await _plugin.cancel(_idRecordatorio);

    const detalles = NotificationDetails(
      android: AndroidNotificationDetails(
        'mi_presupuesto_recordatorio',
        'Recordatorio diario',
        channelDescription: 'Recordatorio para registrar movimientos',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        icon: '@mipmap/ic_launcher',
      ),
    );

    await _plugin.periodicallyShow(
      _idRecordatorio,
      '📝 ¿Ya registraste tus movimientos?',
      'Mantener el registro al día mejora tu análisis financiero.',
      RepeatInterval.daily,
      detalles,
      androidScheduleMode: AndroidScheduleMode.inexact,
    );
  }

  // ── Cancelar recordatorio diario ──────────────────────────
  static Future<void> cancelarRecordatorioDiario() async {
    await _plugin.cancel(_idRecordatorio);
  }

  // ── Analizar y disparar notificaciones inteligentes ───────
  static Future<void> analizarYNotificar() async {
    final ok = await inicializar();
    if (!ok) return;

    final brain = MasterFinancialBrain.instance;
    final db = DatabaseHelper.instance;

    // Una sola llamada al brain — único punto de verdad.
    final result = await brain.analizar();
    final analysis = result.analysis;

    // 1. PRESUPUESTO AL 80%
    if (analysis.ingresos > 0) {
      final double ratioGasto = analysis.gastos / analysis.ingresos;
      if (ratioGasto >= 0.8) {
        await _mostrar(
          id: _idPresupuesto,
          titulo:
              '⚠️ Presupuesto al ${(ratioGasto * 100).toStringAsFixed(0)}%',
          cuerpo:
              'Has usado el ${(ratioGasto * 100).toStringAsFixed(0)}% de tus ingresos '
              'en gastos operativos. Te quedan '
              '\$${analysis.dineroDisponible.toStringAsFixed(0)} disponibles.',
          importancia: ratioGasto >= 0.95
              ? Importance.high
              : Importance.defaultImportance,
          prioridad: ratioGasto >= 0.95
              ? Priority.high
              : Priority.defaultPriority,
        );
      }
    }

    // 2. DÍAS SIN REGISTRAR MOVIMIENTOS
    final movimientos = await db.obtenerMovimientos();
    if (movimientos.isNotEmpty) {
      final movimientosOrdenados = List<Map<String, dynamic>>.from(movimientos)
        ..sort((a, b) => DateTime.parse(b['fecha'])
            .compareTo(DateTime.parse(a['fecha'])));

      final ultimaFecha = DateTime.parse(movimientosOrdenados.first['fecha']);
      final diasSinRegistro = DateTime.now().difference(ultimaFecha).inDays;

      if (diasSinRegistro >= 3) {
        await _mostrar(
          id: _idSinRegistros,
          titulo: '📋 Llevas $diasSinRegistro días sin registrar',
          cuerpo:
              'El registro constante mejora la precisión de tu análisis financiero. '
              '¡Actualiza tus movimientos!',
        );
      }
    }

    // 3. METAS EN RIESGO Y VENCIDAS
    final metasData = await db.obtenerMetas();
    if (metasData.isNotEmpty) {
      final metas = metasData.map((e) => MetaAhorro.fromMap(e)).toList();
      final metaEngine = MetaInteligenteEngine();
      // Pasamos el result al engine migrado (firma nueva).
      final metasInteligentes = await metaEngine.analizarMetas(metas, result);

      final metasVencidas = metasInteligentes
          .where((m) => m.estado == 'VENCIDA')
          .toList();

      if (metasVencidas.isNotEmpty) {
        final nombres = metasVencidas.take(2).map((m) => m.nombre).join(' y ');
        await _mostrar(
          id: _idMetaVencida,
          titulo: '📅 ${metasVencidas.length == 1 ? "Meta vencida" : "Metas vencidas"}',
          cuerpo:
              '$nombres ${metasVencidas.length == 1 ? "venció" : "vencieron"} '
              'sin completarse. Actualiza la fecha para seguir ahorrando.',
          importancia: Importance.high,
          prioridad: Priority.high,
        );
      }

      final metasEnRiesgo = metasInteligentes
          .where((m) => m.estado == 'EN_RIESGO')
          .toList();

      if (metasEnRiesgo.isNotEmpty) {
        final nombres =
            metasEnRiesgo.take(2).map((m) => m.nombre).join(' y ');
        await _mostrar(
          id: _idMeta,
          titulo: '🎯 Meta en riesgo',
          cuerpo:
              '$nombres ${metasEnRiesgo.length == 1 ? "está" : "están"} '
              'en riesgo de no cumplirse a tiempo.',
        );
      }
    }

    // 4. GASTOS AUMENTARON SIGNIFICATIVAMENTE
    final cambioGastos = await _calcularCambioGastosMesAnterior(db);
    if (cambioGastos > 20) {
      await _mostrar(
        id: _idGastos,
        titulo:
            '📈 Gastos aumentaron ${cambioGastos.toStringAsFixed(1)}%',
        cuerpo:
            'Tus gastos operativos subieron significativamente respecto al mes pasado. '
            'Revisa en qué categoría está el aumento.',
        importancia: cambioGastos > 40
            ? Importance.high
            : Importance.defaultImportance,
        prioridad: cambioGastos > 40
            ? Priority.high
            : Priority.defaultPriority,
      );
    }
  }

  /// Calcula el cambio porcentual de gastos operativos respecto al mes anterior.
  /// Excluye movimientos marcados como deuda (estos viven en su tabla aparte).
  static Future<double> _calcularCambioGastosMesAnterior(
    DatabaseHelper db,
  ) async {
    final ahora = DateTime.now();
    final mesActualData =
        await db.obtenerMovimientosPorMes(ahora.year, ahora.month);

    final yearAnterior = ahora.month == 1 ? ahora.year - 1 : ahora.year;
    final mesAnterior = ahora.month == 1 ? 12 : ahora.month - 1;
    final mesAnteriorData =
        await db.obtenerMovimientosPorMes(yearAnterior, mesAnterior);

    double sumarGastosOperativos(List<Map<String, dynamic>> mov) {
      double total = 0;
      for (final m in mov) {
        final tipo = (m['tipo'] as String?)?.toLowerCase();
        final esDeuda = (m['es_deuda'] ?? 0) == 1;
        if (tipo == 'gasto' && !esDeuda) {
          total += (m['valor'] as num).toDouble();
        }
      }
      return total;
    }

    final gastosActual = sumarGastosOperativos(mesActualData);
    final gastosAnterior = sumarGastosOperativos(mesAnteriorData);

    if (gastosAnterior == 0) return 0;
    return ((gastosActual - gastosAnterior) / gastosAnterior) * 100;
  }

  // ── Cancelar todas ────────────────────────────────────────
  static Future<void> cancelarTodas() async {
    await _plugin.cancelAll();
  }
}
