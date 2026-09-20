import '../database_helper.dart';
import '../models/celda_foto.dart';

/// CRUD de las fotos de evidencia de cada celda.
class CeldaFotoRepository {
  CeldaFotoRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insert(CeldaFoto foto) async {
    final db = await _db.database;
    final map = foto.toMap()..remove('id');
    return db.insert(DatabaseHelper.tableFotos, map);
  }

  Future<List<CeldaFoto>> byCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableFotos,
      where: 'celda_id = ?',
      whereArgs: [celdaId],
      orderBy: 'fecha ASC, id ASC',
    );
    return rows.map(CeldaFoto.fromMap).toList();
  }

  Future<int> countByCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${DatabaseHelper.tableFotos} '
      'WHERE celda_id = ?',
      [celdaId],
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Cuenta las fotos de todas las celdas de una vez (para las listas).
  Future<Map<int, int>> countsByCelda() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT celda_id, COUNT(*) AS n FROM ${DatabaseHelper.tableFotos} '
      'GROUP BY celda_id',
    );
    return {
      for (final r in rows) (r['celda_id'] as int? ?? 0): (r['n'] as int?) ?? 0,
    };
  }

  Future<void> update(CeldaFoto foto) async {
    if (foto.id == null) return;
    final db = await _db.database;
    await db.update(
      DatabaseHelper.tableFotos,
      foto.toMap(),
      where: 'id = ?',
      whereArgs: [foto.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.tableFotos,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Borra las referencias de todas las fotos de una celda.
  ///
  /// Devuelve las rutas afectadas para que quien llame pueda borrar los
  /// archivos del disco.
  Future<List<String>> deleteByCelda(int celdaId) async {
    final db = await _db.database;
    final fotos = await byCelda(celdaId);
    await db.delete(
      DatabaseHelper.tableFotos,
      where: 'celda_id = ?',
      whereArgs: [celdaId],
    );
    return fotos.map((f) => f.path).toList();
  }
}
