import '../database_helper.dart';
import '../models/cell_test.dart';

/// CRUD de tests/mediciones por celda.
class CellTestRepository {
  CellTestRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insert(CellTest test) async {
    final db = await _db.database;
    final map = test.toMap()..remove('id');
    return db.insert(DatabaseHelper.tableTests, map);
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.tableTests,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<CellTest>> byCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableTests,
      where: 'celda_id = ?',
      whereArgs: [celdaId],
      orderBy: 'fecha DESC',
    );
    return rows.map(CellTest.fromMap).toList();
  }

  /// Último test registrado a una celda (el que define su clasificación).
  Future<CellTest?> lastByCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableTests,
      where: 'celda_id = ?',
      whereArgs: [celdaId],
      orderBy: 'fecha DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : CellTest.fromMap(rows.first);
  }

  Future<int> countByCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${DatabaseHelper.tableTests} '
      'WHERE celda_id = ?',
      [celdaId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// El último test de **cada** celda, en una sola consulta.
  ///
  /// La agrupación necesita la medición más reciente de muchas celdas a la vez.
  /// Pedirlas una por una serían cientos de consultas; así se resuelve en una.
  /// El desempate por `id` es para que, si dos tests comparten fecha, gane
  /// siempre el mismo (el último registrado) y el resultado no baile.
  Future<Map<int, CellTest>> ultimosPorCelda() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT t.* FROM ${DatabaseHelper.tableTests} t '
      'WHERE t.id = ('
      '  SELECT t2.id FROM ${DatabaseHelper.tableTests} t2 '
      '  WHERE t2.celda_id = t.celda_id '
      '  ORDER BY t2.fecha DESC, t2.id DESC LIMIT 1'
      ')',
    );
    return {
      for (final r in rows) (r['celda_id'] as int): CellTest.fromMap(r),
    };
  }
}
