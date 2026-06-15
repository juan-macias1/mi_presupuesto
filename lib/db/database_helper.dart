import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// DatabaseHelper — capa única de acceso a SQLite.
///
/// Maneja la creación, migración y operaciones CRUD sobre las tablas:
/// movimientos, categorias, metas, deudas.
///
/// Lleva un contador estático `dataVersion` que se incrementa en cada
/// escritura. MasterFinancialBrain lo compara contra su versión cacheada
/// para detectar cambios automáticamente, sin que cada pantalla deba
/// acordarse de llamar a `invalidarCache()` manualmente.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  // ═══════════════════════════════════════════════════════════
  // CONTADOR DE VERSIÓN DE DATOS
  // ═══════════════════════════════════════════════════════════

  /// Se incrementa en cada operación de escritura (insert/update/delete).
  /// MasterFinancialBrain compara este número contra el suyo cacheado
  /// para saber si los datos cambiaron desde el último análisis.
  ///
  /// Centralizar la invalidación acá evita el bug clásico de "olvidé
  /// llamar a invalidarCache() en esa nueva pantalla que escribe a la DB".
  static int _dataVersion = 0;
  static int get dataVersion => _dataVersion;
  static void _bumpVersion() => _dataVersion++;

  // ═══════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'presupuesto.db');
    return await openDatabase(
      path,
      // v5: agrega deuda_id en movimientos para vincular pagos a deudas.
      version: 5,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Creación completa desde cero ──────────────────────────
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE movimientos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo TEXT,
        categoria TEXT,
        descripcion TEXT,
        valor REAL,
        fecha TEXT,
        es_fijo INTEGER DEFAULT 0,
        es_deuda INTEGER DEFAULT 0,
        acreedor TEXT,
        deuda_id INTEGER REFERENCES deudas(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE categorias (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        emoji TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE metas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT,
        montoObjetivo REAL,
        montoAhorrado REAL,
        fechaObjetivo TEXT,
        fechaCreacion TEXT,
        activa INTEGER
      )
    ''');

    // Tabla deudas — saldos reales, no cuotas acumuladas.
    await db.execute('''
      CREATE TABLE deudas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        acreedor TEXT NOT NULL,
        descripcion TEXT,
        saldo_inicial REAL NOT NULL,
        saldo_actual REAL NOT NULL,
        cuota_mensual REAL NOT NULL,
        tasa_interes REAL DEFAULT 0,
        fecha_inicio TEXT NOT NULL,
        fecha_estimada_pago TEXT,
        activa INTEGER DEFAULT 1,
        orden_pago INTEGER DEFAULT 0
      )
    ''');
  }

  // ── Migraciones seguras ───────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // v1 → v2: campos de gasto fijo y deuda en movimientos
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE movimientos ADD COLUMN es_fijo INTEGER DEFAULT 0",
      );
      await db.execute(
        "ALTER TABLE movimientos ADD COLUMN es_deuda INTEGER DEFAULT 0",
      );
      await db.execute("ALTER TABLE movimientos ADD COLUMN acreedor TEXT");
    }

    // v2 → v3: tabla metas
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS metas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          montoObjetivo REAL,
          montoAhorrado REAL,
          fechaObjetivo TEXT,
          fechaCreacion TEXT,
          activa INTEGER
        )
      ''');
    }

    // v3 → v4: tabla deudas reales
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS deudas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          acreedor TEXT NOT NULL,
          descripcion TEXT,
          saldo_inicial REAL NOT NULL,
          saldo_actual REAL NOT NULL,
          cuota_mensual REAL NOT NULL,
          tasa_interes REAL DEFAULT 0,
          fecha_inicio TEXT NOT NULL,
          fecha_estimada_pago TEXT,
          activa INTEGER DEFAULT 1,
          orden_pago INTEGER DEFAULT 0
        )
      ''');
    }

    // v4 → v5: vínculo entre movimiento y deuda.
    // Cuando registro un pago de cuota como gasto, lo apunto a la deuda
    // que estoy pagando con `deuda_id`. El saldo de la deuda se calcula
    // como saldo_inicial − suma de movimientos vinculados (no se guarda).
    // Los movimientos viejos quedan con deuda_id = NULL, sin perder nada.
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE movimientos ADD COLUMN deuda_id INTEGER "
        "REFERENCES deudas(id) ON DELETE SET NULL",
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // MOVIMIENTOS
  // ═══════════════════════════════════════════════════════════

  Future<int> insertarMovimiento(Map<String, dynamic> movimiento) async {
    final db = await database;
    final id = await db.insert(
      'movimientos',
      movimiento,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _bumpVersion();
    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerMovimientos() async {
    final db = await database;
    return await db.query('movimientos', orderBy: 'fecha DESC');
  }

  /// Movimientos solo del mes actual — base del análisis mensual real.
  Future<List<Map<String, dynamic>>> obtenerMovimientosMesActual() async {
    final db = await database;
    final ahora = DateTime.now();
    final inicio = DateTime(ahora.year, ahora.month, 1).toIso8601String();
    final fin = DateTime(
      ahora.year,
      ahora.month + 1,
      0,
      23,
      59,
      59,
    ).toIso8601String();

    return await db.query(
      'movimientos',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [inicio, fin],
      orderBy: 'fecha DESC',
    );
  }

  /// Movimientos de un mes específico — para tendencias históricas.
  Future<List<Map<String, dynamic>>> obtenerMovimientosPorMes(
    int year,
    int month,
  ) async {
    final db = await database;
    final inicio = DateTime(year, month, 1).toIso8601String();
    final fin = DateTime(year, month + 1, 0, 23, 59, 59).toIso8601String();

    return await db.query(
      'movimientos',
      where: 'fecha >= ? AND fecha <= ?',
      whereArgs: [inicio, fin],
      orderBy: 'fecha DESC',
    );
  }

  Future<int> actualizarMovimiento(Map<String, dynamic> movimiento) async {
    final db = await database;
    final result = await db.update(
      'movimientos',
      movimiento,
      where: 'id = ?',
      whereArgs: [movimiento['id']],
    );
    _bumpVersion();
    return result;
  }

  Future<int> eliminarMovimiento(int id) async {
    final db = await database;
    final result = await db.delete(
      'movimientos',
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  Future<void> borrarTodo() async {
    final db = await database;
    await db.delete('movimientos');
    _bumpVersion();
  }

  // ═══════════════════════════════════════════════════════════
  // CATEGORÍAS
  // ═══════════════════════════════════════════════════════════

  Future<int> insertarCategoria(Map<String, dynamic> categoria) async {
    final db = await database;
    final id = await db.insert('categorias', categoria);
    _bumpVersion();
    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerCategorias() async {
    final db = await database;
    return await db.query('categorias', orderBy: 'nombre ASC');
  }

  Future<int> eliminarCategoria(int id) async {
    final db = await database;
    final result = await db.delete(
      'categorias',
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  // ═══════════════════════════════════════════════════════════
  // METAS
  // ═══════════════════════════════════════════════════════════

  Future<int> insertarMeta(Map<String, dynamic> meta) async {
    final db = await database;
    final id = await db.insert('metas', meta);
    _bumpVersion();
    return id;
  }

  Future<List<Map<String, dynamic>>> obtenerMetas() async {
    final db = await database;
    return await db.query('metas', orderBy: 'fechaObjetivo ASC');
  }

  Future<int> actualizarMeta(Map<String, dynamic> meta, int id) async {
    final db = await database;
    final result = await db.update(
      'metas',
      meta,
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  Future<int> eliminarMeta(int id) async {
    final db = await database;
    final result = await db.delete('metas', where: 'id = ?', whereArgs: [id]);
    _bumpVersion();
    return result;
  }

  // ═══════════════════════════════════════════════════════════
  // DEUDAS — tabla nueva v4
  // ═══════════════════════════════════════════════════════════

  /// Insertar deuda nueva con saldo real.
  Future<int> insertarDeuda(Map<String, dynamic> deuda) async {
    final db = await database;
    final id = await db.insert(
      'deudas',
      deuda,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _bumpVersion();
    return id;
  }

  /// Obtener todas las deudas activas ordenadas por orden de pago.
  Future<List<Map<String, dynamic>>> obtenerDeudas() async {
    final db = await database;
    return await db.query(
      'deudas',
      where: 'activa = ?',
      whereArgs: [1],
      orderBy: 'orden_pago ASC, saldo_actual ASC',
    );
  }

  /// Obtener todas las deudas incluyendo las pagadas (para historial).
  Future<List<Map<String, dynamic>>> obtenerTodasLasDeudas() async {
    final db = await database;
    return await db.query('deudas', orderBy: 'activa DESC, orden_pago ASC');
  }

  /// Actualizar saldo después de un pago. Si llega a 0 o menos,
  /// marca la deuda como inactiva automáticamente.
  Future<int> actualizarSaldoDeuda(int id, double nuevoSaldo) async {
    final db = await database;
    final activa = nuevoSaldo > 0 ? 1 : 0;
    final result = await db.update(
      'deudas',
      {
        'saldo_actual': nuevoSaldo,
        'activa': activa,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  /// Actualizar deuda completa (cuota, descripción, etc.).
  Future<int> actualizarDeuda(Map<String, dynamic> deuda) async {
    final db = await database;
    final result = await db.update(
      'deudas',
      deuda,
      where: 'id = ?',
      whereArgs: [deuda['id']],
    );
    _bumpVersion();
    return result;
  }

  /// Marcar deuda como pagada sin eliminarla (para historial).
  Future<int> marcarDeudaPagada(int id) async {
    final db = await database;
    final result = await db.update(
      'deudas',
      {'saldo_actual': 0, 'activa': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  Future<int> eliminarDeuda(int id) async {
    final db = await database;
    final result = await db.delete(
      'deudas',
      where: 'id = ?',
      whereArgs: [id],
    );
    _bumpVersion();
    return result;
  }

  /// Total de deuda real pendiente — para el motor.
  Future<double> obtenerTotalDeudaReal() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(saldo_actual) as total FROM deudas WHERE activa = 1',
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ═══════════════════════════════════════════════════════════
  // MODO DE LA APP — deuda vs libertad financiera
  // ═══════════════════════════════════════════════════════════

  /// Detecta automáticamente el modo según si hay deudas activas.
  Future<String> obtenerModoApp() async {
    final totalDeuda = await obtenerTotalDeudaReal();
    return totalDeuda > 0 ? 'DEUDA' : 'LIBERTAD';
  }
}
