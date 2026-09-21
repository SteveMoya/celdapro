import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos local (SQLite) de CeldaPro. Sin backend, sin cuentas.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'celdapro.db';
  static const _dbVersion = 4;

  static const tableLotes = 'lotes';
  static const tableCeldas = 'celdas';
  static const tableTests = 'tests';
  static const tableEventos = 'eventos';
  static const tableFotos = 'celda_fotos';
  static const tablePrefs = 'prefs';

  Database? _db;

  /// Base de datos alternativa para las pruebas (SQLite en memoria).
  ///
  /// En los tests no existe el almacenamiento de Android, así que se le pasa
  /// una base ya abierta: así se prueban los repositorios, los filtros y las
  /// migraciones contra SQLite **de verdad**, no contra dobles.
  static Database? baseDePruebas;

  Future<Database> get database async {
    final pruebas = baseDePruebas;
    if (pruebas != null) return pruebas;
    return _db ??= await _open();
  }

  /// Ruta del archivo de base de datos en el dispositivo.
  static Future<String> ruta() async =>
      p.join(await getDatabasesPath(), _dbName);

  /// Cierra la base de datos para poder copiar el archivo con seguridad.
  ///
  /// Se usa antes de un respaldo o una restauración: copiar un SQLite abierto
  /// puede dar un archivo a medias.
  Future<void> cerrar() async {
    final pruebas = baseDePruebas;
    if (pruebas != null) {
      await pruebas.close();
      baseDePruebas = null;
      return;
    }
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
    return abrirEn(p.join(dir, _dbName));
  }

  /// Abre la base en [ruta] creándola o migrándola como corresponde.
  ///
  /// Está separado de [database] para poder abrir una base **concreta** en los
  /// tests (un archivo con el esquema viejo) y comprobar que la migración real
  /// conserva los datos, en vez de probar una copia de la migración.
  static Future<Database> abrirEn(String ruta) => openDatabase(
        ruta,
        version: _dbVersion,
        onConfigure: (db) async {
          // Integridad referencial (necesario activarlo en SQLite).
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async => _createAll(db),
        onUpgrade: (db, oldVersion, newVersion) async =>
            _actualizar(db, oldVersion),
      );

  /// Migraciones, en orden. Cada bloque comprueba desde qué versión viene.
  static Future<void> _actualizar(Database db, int oldVersion) async {
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
    // v4: los códigos de lote no se pueden repetir.
    if (oldVersion < 4) {
      // La base vieja podía tener dos lotes con el mismo código (algo que
      // confunde al taller: dos "L-2026-09-A" distintos). Antes de exigir
      // unicidad hay que deshacer los que ya chocaban, conservando ambos
      // lotes en vez de borrar ninguno.
      await _liberarCodigosLoteRepetidos(db);
      await _crearIndiceLotesUnico(db);
    }
  }

  /// Renombra los códigos de lote repetidos (`X` → `X-2`, `X-3`…) para poder
  /// exigir unicidad sin perder ningún lote.
  static Future<void> _liberarCodigosLoteRepetidos(Database db) async {
    final filas = await db.query(
      tableLotes,
      columns: ['id', 'codigo'],
      orderBy: 'id ASC',
    );
    final usados = <String>{};
    for (final fila in filas) {
      final id = fila['id'] as int;
      final codigo = (fila['codigo'] as String?) ?? '';
      // El primero con ese código se queda como está.
      if (usados.add(codigo)) continue;
      var n = 2;
      var candidato = '$codigo-$n';
      while (!usados.add(candidato)) {
        n++;
        candidato = '$codigo-$n';
      }
      await db.update(
        tableLotes,
        {'codigo': candidato},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  static Future<void> _crearIndiceLotesUnico(Database db) async {
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_lotes_codigo '
      'ON $tableLotes(codigo)',
    );
  }

  static Future<void> _createAll(Database db) async {
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
    // El código identifica al lote: dos lotes con el mismo código serían
    // indistinguibles en el taller.
    await _crearIndiceLotesUnico(db);

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
  static Future<void> _crearTablaFotos(Database db) async {
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
