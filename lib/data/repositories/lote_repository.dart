import '../database_helper.dart';
import '../models/lote.dart';

/// CRUD de lotes.
class LoteRepository {
  LoteRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insert(Lote lote) async {
    final db = await _db.database;
    final map = lote.toMap()..remove('id');
    return db.insert(DatabaseHelper.tableLotes, map);
  }

  Future<void> update(Lote lote) async {
    if (lote.id == null) return;
    final db = await _db.database;
    await db.update(
      DatabaseHelper.tableLotes,
      lote.toMap(),
      where: 'id = ?',
      whereArgs: [lote.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.tableLotes,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Lote>> all() async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableLotes,
      orderBy: 'fecha_recepcion DESC',
    );
    return rows.map(Lote.fromMap).toList();
  }

  Future<Lote?> byId(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableLotes,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Lote.fromMap(rows.first);
  }

  /// Códigos de lote existentes (para sugerir el siguiente).
  Future<List<String>> codigos() async {
    final db = await _db.database;
    final rows = await db.query(DatabaseHelper.tableLotes, columns: ['codigo']);
    return rows.map((r) => r['codigo'] as String).toList();
  }
}
