import '../database_helper.dart';
import '../models/celda.dart';
import '../../core/classification.dart';

/// Filtros de búsqueda del inventario.
class CeldaFilter {
  const CeldaFilter({
    this.texto,
    this.estado,
    this.veredicto,
    this.loteId,
  });

  final String? texto;
  final CellState? estado;
  final Verdict? veredicto;
  final int? loteId;

  bool get isEmpty =>
      (texto == null || texto!.trim().isEmpty) &&
      estado == null &&
      veredicto == null &&
      loteId == null;
}

/// CRUD y consultas de celdas.
class CeldaRepository {
  CeldaRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insert(Celda celda) async {
    final db = await _db.database;
    final map = celda.toMap()..remove('id');
    return db.insert(DatabaseHelper.tableCeldas, map);
  }

  Future<void> update(Celda celda) async {
    if (celda.id == null) return;
    final db = await _db.database;
    await db.update(
      DatabaseHelper.tableCeldas,
      celda.toMap(),
      where: 'id = ?',
      whereArgs: [celda.id],
    );
  }

  Future<void> delete(int id) async {
    final db = await _db.database;
    await db.delete(
      DatabaseHelper.tableCeldas,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Celda?> byId(int id) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Celda.fromMap(rows.first);
  }

  Future<bool> existsCodigo(String codigo, {int? exceptId}) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      columns: ['id'],
      where: exceptId == null
          ? 'codigo_interno = ?'
          : 'codigo_interno = ? AND id != ?',
      whereArgs: exceptId == null ? [codigo] : [codigo, exceptId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<List<Celda>> all({
    CeldaFilter filter = const CeldaFilter(),
    String orderBy = 'codigo_interno ASC',
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <Object?>[];

    final texto = filter.texto?.trim();
    if (texto != null && texto.isNotEmpty) {
      where.add(
        '(codigo_interno LIKE ? OR qr LIKE ? OR marca LIKE ? OR modelo LIKE ?)',
      );
      final like = '%$texto%';
      args.addAll([like, like, like, like]);
    }
    if (filter.estado != null) {
      where.add('estado = ?');
      args.add(filter.estado!.name);
    }
    if (filter.veredicto != null) {
      where.add('veredicto = ?');
      args.add(filter.veredicto!.name);
    }
    if (filter.loteId != null) {
      where.add('lote_id = ?');
      args.add(filter.loteId);
    }

    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: orderBy,
    );
    return rows.map(Celda.fromMap).toList();
  }

  Future<List<Celda>> byLote(int loteId) =>
      all(filter: CeldaFilter(loteId: loteId));

  /// Conteo de celdas por estado.
  Future<Map<CellState, int>> countByEstado() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT estado, COUNT(*) AS n FROM ${DatabaseHelper.tableCeldas} '
      'GROUP BY estado',
    );
    final out = <CellState, int>{};
    for (final r in rows) {
      out[CellState.fromName(r['estado'] as String?)] = (r['n'] as int?) ?? 0;
    }
    return out;
  }

  /// Conteo de celdas por veredicto.
  Future<Map<Verdict, int>> countByVeredicto() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT veredicto, COUNT(*) AS n FROM ${DatabaseHelper.tableCeldas} '
      'WHERE veredicto IS NOT NULL GROUP BY veredicto',
    );
    final out = <Verdict, int>{};
    for (final r in rows) {
      final v = Verdict.fromName(r['veredicto'] as String?);
      out[v] = (r['n'] as int?) ?? 0;
    }
    return out;
  }

  /// Capacidad medida promedio de las celdas con SoH calculado.
  Future<double?> averageSoh() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT AVG(soh_pct) AS avg FROM ${DatabaseHelper.tableCeldas} '
      'WHERE soh_pct IS NOT NULL',
    );
    return (rows.first['avg'] as num?)?.toDouble();
  }

  Future<int> total() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${DatabaseHelper.tableCeldas}',
    );
    return (rows.first['n'] as int?) ?? 0;
  }
}
