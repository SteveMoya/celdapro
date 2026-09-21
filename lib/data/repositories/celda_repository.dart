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
    this.sohMin,
    this.sohMax,
    this.capacidadMin,
    this.capacidadMax,
  });

  final String? texto;
  final CellState? estado;
  final Verdict? veredicto;
  final int? loteId;

  /// Rango de SoH (%). Solo entran las celdas que ya tienen medición.
  final double? sohMin;
  final double? sohMax;

  /// Rango de capacidad nominal (mAh).
  final double? capacidadMin;
  final double? capacidadMax;

  bool get isEmpty =>
      (texto == null || texto!.trim().isEmpty) &&
      estado == null &&
      veredicto == null &&
      loteId == null &&
      sohMin == null &&
      sohMax == null &&
      capacidadMin == null &&
      capacidadMax == null;

  /// ¿Hay algún filtro por rango puesto?
  bool get tieneRangos =>
      sohMin != null || sohMax != null || capacidadMin != null || capacidadMax != null;

  CeldaFilter copyWith({
    String? texto,
    CellState? estado,
    Verdict? veredicto,
    int? loteId,
    double? sohMin,
    double? sohMax,
    double? capacidadMin,
    double? capacidadMax,
    bool limpiarRangos = false,
  }) =>
      CeldaFilter(
        texto: texto ?? this.texto,
        estado: estado ?? this.estado,
        veredicto: veredicto ?? this.veredicto,
        loteId: loteId ?? this.loteId,
        sohMin: limpiarRangos ? null : (sohMin ?? this.sohMin),
        sohMax: limpiarRangos ? null : (sohMax ?? this.sohMax),
        capacidadMin: limpiarRangos ? null : (capacidadMin ?? this.capacidadMin),
        capacidadMax: limpiarRangos ? null : (capacidadMax ?? this.capacidadMax),
      );
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
    final (where, args) = _condiciones(filter);
    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      where: where,
      whereArgs: args,
      orderBy: orderBy,
    );
    return rows.map(Celda.fromMap).toList();
  }

  /// Una página del inventario.
  ///
  /// Con miles de celdas, traerlas todas de golpe al abrir la lista hace que
  /// la app tarde y gaste memoria sin necesidad: solo se ven las primeras.
  /// Devuelve [limite] filas a partir de [desplazamiento].
  Future<List<Celda>> pagina({
    CeldaFilter filter = const CeldaFilter(),
    String orderBy = 'codigo_interno ASC',
    required int limite,
    int desplazamiento = 0,
  }) async {
    final db = await _db.database;
    final (where, args) = _condiciones(filter);
    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      where: where,
      whereArgs: args,
      orderBy: orderBy,
      limit: limite,
      offset: desplazamiento,
    );
    return rows.map(Celda.fromMap).toList();
  }

  /// Cuántas celdas cumplen el filtro (para saber si hay más páginas).
  Future<int> contar({CeldaFilter filter = const CeldaFilter()}) async {
    final db = await _db.database;
    final (where, args) = _condiciones(filter);
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS n FROM ${DatabaseHelper.tableCeldas}'
      '${where == null ? '' : ' WHERE $where'}',
      args,
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  /// Las celdas que todavía no tienen medición (para el registro en serie).
  ///
  /// Se resuelve en la base y no sobre la lista cargada: con paginación, la
  /// lista en memoria es solo una parte del inventario.
  Future<List<Celda>> sinMedir({
    CeldaFilter filter = const CeldaFilter(),
  }) async {
    final db = await _db.database;
    final (where, args) = _condiciones(filter);
    final rows = await db.query(
      DatabaseHelper.tableCeldas,
      where: where == null ? 'soh_pct IS NULL' : '($where) AND soh_pct IS NULL',
      whereArgs: args,
      orderBy: 'codigo_interno ASC',
    );
    return rows.map(Celda.fromMap).toList();
  }

  /// Traduce el filtro a SQL. Devuelve (condición, argumentos); la condición
  /// es null cuando no hay nada que filtrar.
  (String?, List<Object?>?) _condiciones(CeldaFilter filter) {
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
    // Los rangos sobre el SoH solo tienen sentido en celdas ya medidas.
    if (filter.sohMin != null) {
      where.add('soh_pct IS NOT NULL AND soh_pct >= ?');
      args.add(filter.sohMin);
    }
    if (filter.sohMax != null) {
      where.add('soh_pct IS NOT NULL AND soh_pct <= ?');
      args.add(filter.sohMax);
    }
    if (filter.capacidadMin != null) {
      where.add('capacidad_nominal_mah IS NOT NULL AND capacidad_nominal_mah >= ?');
      args.add(filter.capacidadMin);
    }
    if (filter.capacidadMax != null) {
      where.add('capacidad_nominal_mah IS NOT NULL AND capacidad_nominal_mah <= ?');
      args.add(filter.capacidadMax);
    }

    return (where.isEmpty ? null : where.join(' AND '),
        args.isEmpty ? null : args);
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
