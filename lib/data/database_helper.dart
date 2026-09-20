import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (SQLite) de CeldaPro. Sin backend, sin cuentas.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'celdapro.db';
  static const _dbVersion = 3;

  static const tableLotes = 'lotes';
  static const tableCeldas = 'celdas';
  static const tableTests = 'tests';
  static const tableEventos = 'eventos';
  static const tableFotos = 'celda_fotos';
  static const tablePrefs = 'prefs';

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  /// Ruta del archivo de base de datos en el dispositivo.
  static Future<String> ruta() async =>
      p.join(await getDatabasesPath(), _dbName);

  /// Cierra la base de datos para poder copiar el archivo con seguridad.
  ///
  /// Se usa antes de un respaldo o una restauración: copiar un SQLite abierto
  /// puede dar un archivo a medias.
  Future<void> cerrar() async {
    await _db?.close();
    _db = null;
  }

  /// Reabre la base de datos tras un respaldo o una restauración.
  Future<void> reabrir() async => database;

  /// Cuenta las filas de las cuatro tablas principales.
  Future<Map<String, int>> contar() async {
    final base = await database;
    Future<int> n(String tabla) async {
      final r = await base.rawQuery('SELECT COUNT(*) AS n FROM $tabla');
      return (r.first['n'] as int?) ?? 0;
    }

    return {
      'celdas': await n(tableCeldas),
      'lotes': await n(tableLotes),
      'tests': await n(tableTests),
      'eventos': await n(tableEventos),
    };
  }

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
      onUpgrade: (db, oldVersion, newVersion) async {
        // v2: referencia del catálogo de celdas y resistencia interna nominal.
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE $tableCeldas ADD COLUMN catalog_ref TEXT',
          );
          await db.execute(
            'ALTER TABLE $tableCeldas ADD COLUMN ir_nominal_mohm REAL',
          );
        }
        // v3: varias fotos por celda, con etiqueta.
        if (oldVersion < 3) {
          await _crearTablaFotos(db);
          // La foto que ya existía pasa a ser la primera de la galería, para
          // que nadie pierda la evidencia que ya tenía registrada.
          await db.execute('''
            INSERT INTO $tableFotos (celda_id, path, etiqueta, fecha)
            SELECT id, foto_path, 'evidence', created_at
            FROM $tableCeldas
            WHERE foto_path IS NOT NULL AND foto_path != ''
          ''');
        }
      },
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
        catalog_ref TEXT,
        ir_nominal_mohm REAL,
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

    await _crearTablaFotos(db);

    await db.execute('''
      CREATE TABLE $tablePrefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Galería de fotos de evidencia de cada celda.
  Future<void> _crearTablaFotos(Database db) async {
    await db.execute('''
      CREATE TABLE $tableFotos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        celda_id INTEGER NOT NULL REFERENCES $tableCeldas(id) ON DELETE CASCADE,
        path TEXT NOT NULL,
        etiqueta TEXT NOT NULL,
        fecha INTEGER NOT NULL,
        nota TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_fotos_celda ON $tableFotos(celda_id)',
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
