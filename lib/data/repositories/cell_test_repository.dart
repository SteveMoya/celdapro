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
}
