import '../database_helper.dart';
import '../models/cell_event.dart';

/// Registro/historial de trazabilidad por celda.
class CellEventRepository {
  CellEventRepository({DatabaseHelper? dbHelper})
      : _db = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  Future<int> insert(CellEvent event) async {
    final db = await _db.database;
    final map = event.toMap()..remove('id');
    return db.insert(DatabaseHelper.tableEventos, map);
  }

  /// Atajo: registra un cambio de estado.
  Future<void> logStateChange({
    required int celdaId,
    required String? from,
    required String to,
    String? nota,
  }) =>
      insert(
        CellEvent(
          celdaId: celdaId,
          tipo: EventType.stateChanged,
          estadoAnterior: from,
          estadoNuevo: to,
          fecha: DateTime.now(),
          nota: nota,
        ),
      );

  Future<List<CellEvent>> byCelda(int celdaId) async {
    final db = await _db.database;
    final rows = await db.query(
      DatabaseHelper.tableEventos,
      where: 'celda_id = ?',
      whereArgs: [celdaId],
      orderBy: 'fecha DESC',
    );
    return rows.map(CellEvent.fromMap).toList();
  }
}
