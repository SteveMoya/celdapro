import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (SQLite) de CeldaPro. Sin backend, sin cuentas.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'celdapro.db';
  static const _dbVersion = 1;

  static const tableLotes = 'lotes';
  static const tableCeldas = 'celdas';
  static const tableTests = 'tests';
  static const tableEventos = 'eventos';
  static const tablePrefs = 'prefs';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        // Integridad referencial (necesario activarlo explícitamente en SQLite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async => _createAll(db),
    );
  }

  Future<void> _createAll(Database db) async {
    await db.execute('''
      CREATE TABLE $tableLotes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo TEXT NOT NULL,
        proveedor TEXT,
        origen TEXT,
        fecha_recepcion INTEGER NOT NULL,
        notas TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableCeldas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lote_id INTEGER REFERENCES $tableLotes(id) ON DELETE SET NULL,
        codigo_interno TEXT NOT NULL UNIQUE,
        qr TEXT,
        marca TEXT,
        modelo TEXT,
        quimica TEXT NOT NULL,
        capacidad_nominal_mah REAL,
        voltaje_nominal REAL,
        fecha_fabricacion INTEGER,
        estado TEXT NOT NULL,
        veredicto TEXT,
        soh_pct REAL,
        ubicacion TEXT,
        foto_path TEXT,
        notas TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_celdas_lote ON $tableCeldas(lote_id)');
    await db.execute('CREATE INDEX idx_celdas_estado ON $tableCeldas(estado)');
    await db.execute(
      'CREATE INDEX idx_celdas_veredicto ON $tableCeldas(veredicto)',
    );

    await db.execute('''
      CREATE TABLE $tableTests (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        celda_id INTEGER NOT NULL REFERENCES $tableCeldas(id) ON DELETE CASCADE,
        fecha INTEGER NOT NULL,
        voltaje_v REAL,
        capacidad_medida_mah REAL,
        resistencia_interna_mohm REAL,
        ciclos INTEGER,
        corriente_descarga_a REAL,
        temperatura_c REAL,
        soh_pct REAL,
        veredicto TEXT,
        operador TEXT,
        notas TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_tests_celda ON $tableTests(celda_id)');

    await db.execute('''
      CREATE TABLE $tableEventos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        celda_id INTEGER NOT NULL REFERENCES $tableCeldas(id) ON DELETE CASCADE,
        tipo TEXT NOT NULL,
        estado_anterior TEXT,
        estado_nuevo TEXT,
        fecha INTEGER NOT NULL,
        nota TEXT
      )
    ''');
    await db.execute('CREATE INDEX idx_eventos_celda ON $tableEventos(celda_id)');

    await db.execute('''
      CREATE TABLE $tablePrefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
