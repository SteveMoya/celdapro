import 'package:flutter/foundation.dart';

import '../core/classification.dart';
import '../data/models/celda.dart';
import '../data/models/cell_event.dart';
import '../data/models/cell_test.dart';
import '../data/models/lote.dart';
import '../data/preferences_store.dart';
import '../data/repositories/celda_repository.dart';
import '../data/repositories/cell_event_repository.dart';
import '../data/repositories/cell_test_repository.dart';
import '../data/repositories/lote_repository.dart';
import '../services/photo_service.dart';

/// Estado del inventario: celdas, lotes, métricas y acciones de proceso.
class CeldaController extends ChangeNotifier {
  CeldaController({
    CeldaRepository? celdas,
    LoteRepository? lotes,
    CellTestRepository? tests,
    CellEventRepository? eventos,
    PreferencesStore? prefs,
    PhotoService photoService = const PhotoService(),
  })  : _celdas = celdas ?? CeldaRepository(),
        _lotes = lotes ?? LoteRepository(),
        _tests = tests ?? CellTestRepository(),
        _eventos = eventos ?? CellEventRepository(),
        _prefs = prefs ?? PreferencesStore(),
        _photos = photoService;

  final CeldaRepository _celdas;
  final LoteRepository _lotes;
  final CellTestRepository _tests;
  final CellEventRepository _eventos;
  final PreferencesStore _prefs;
  final PhotoService _photos;

  List<Celda> celdas = const [];
  List<Lote> lotes = const [];
  bool loading = true;
  CeldaFilter filter = const CeldaFilter();

  Thresholds thresholds = const Thresholds();
  List<String> rejectReasons = PreferencesStore.defaultRejectReasons;

  Map<CellState, int> countsByEstado = const {};
  Map<Verdict, int> countsByVeredicto = const {};
  double? avgSoh;
  int total = 0;

  /// Fecha del último respaldo (null si nunca se ha hecho uno).
  DateTime? ultimoRespaldo;

  /// Días desde el último respaldo, o null si no hay ninguno.
  int? get diasSinRespaldo =>
      ultimoRespaldo == null ? null : DateTime.now().difference(ultimoRespaldo!).inDays;

  /// Días tras los cuales conviene recordar el respaldo.
  static const diasAvisoRespaldo = 7;

  bool get tocaRespaldar {
    final d = diasSinRespaldo;
    return d == null || d >= diasAvisoRespaldo;
  }

  // ---------- Carga ----------

  Future<void> init() async {
    thresholds = await _prefs.loadThresholds();
    rejectReasons = await _prefs.loadRejectReasons();
    ultimoRespaldo = await _prefs.loadLastBackup();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();

    celdas = await _celdas.all(filter: filter);
    lotes = await _lotes.all();
    countsByEstado = await _celdas.countByEstado();
    countsByVeredicto = await _celdas.countByVeredicto();
    avgSoh = await _celdas.averageSoh();
    total = await _celdas.total();

    loading = false;
    notifyListeners();
  }

  Future<void> setFilter(CeldaFilter f) async {
    filter = f;
    await refresh();
  }

  // ---------- Métricas ----------

  /// Porcentaje de celdas rechazadas sobre las clasificadas.
  double get rejectionRate {
    final classified = countsByVeredicto.values.fold<int>(0, (a, b) => a + b);
    if (classified == 0) return 0;
    return ((countsByVeredicto[Verdict.reject] ?? 0) / classified) * 100;
  }

  int get classifiedCount =>
      countsByVeredicto.values.fold<int>(0, (a, b) => a + b);

  Map<int, Lote> get lotesById => {
        for (final l in lotes)
          if (l.id != null) l.id!: l,
      };

  // ---------- Celdas ----------

  /// Sugiere el siguiente código interno (C-0001, C-0002…).
  Future<String> suggestCodigo() async {
    final existentes = (await _celdas.all()).map((c) => c.codigoInterno).toSet();
    var n = existentes.length + 1;
    while (true) {
      final candidato = 'C-${n.toString().padLeft(4, '0')}';
      if (!existentes.contains(candidato)) return candidato;
      n++;
    }
  }

  /// Crea una celda. Si se pasa [firstTest], se registra como primera medición
  /// y la celda queda clasificada automáticamente.
  Future<int> addCelda(Celda celda, {CellTest? firstTest}) async {
    var nueva = celda;
    int? id;

    if (firstTest != null) {
      final result = classifyByCapacity(
        measuredMah: firstTest.capacidadMedidaMah,
        nominalMah: celda.capacidadNominalMah,
        thresholds: thresholds,
      );
      nueva = celda.copyWith(
        veredicto: result.verdict,
        sohPct: result.soh,
        estado: CellState.classified,
      );
    }

    id = await _celdas.insert(nueva);

    await _eventos.insert(
      CellEvent(
        celdaId: id,
        tipo: EventType.created,
        estadoNuevo: nueva.estado.name,
        fecha: DateTime.now(),
        nota: 'Alta de celda ${nueva.codigoInterno}',
      ),
    );

    if (firstTest != null) {
      await _saveTest(celdaId: id, test: firstTest, celda: nueva);
    }

    await refresh();
    return id;
  }

  Future<void> updateCelda(Celda celda, {String? nota}) async {
    await _celdas.update(celda);
    if (celda.id != null) {
      await _eventos.insert(
        CellEvent(
          celdaId: celda.id!,
          tipo: EventType.edited,
          fecha: DateTime.now(),
          nota: nota ?? 'Datos de la celda actualizados',
        ),
      );
    }
    await refresh();
  }

  Future<void> deleteCelda(Celda celda) async {
    if (celda.id == null) return;
    await _photos.delete(celda.fotoPath);
    await _celdas.delete(celda.id!);
    await refresh();
  }

  /// Cambia el estado de la celda registrando el evento (trazabilidad).
  Future<void> changeState(Celda celda, CellState nuevo, {String? nota}) async {
    if (celda.id == null || celda.estado == nuevo) return;
    final anterior = celda.estado;
    await _celdas.update(celda.copyWith(estado: nuevo));
    await _eventos.logStateChange(
      celdaId: celda.id!,
      from: anterior.name,
      to: nuevo.name,
      nota: nota,
    );
    await refresh();
  }

  /// Adjunta/reemplaza la foto de evidencia de una celda.
  Future<void> setFoto(Celda celda, String path) async {
    if (celda.id == null) return;
    await _photos.delete(celda.fotoPath);
    await _celdas.update(celda.copyWith(fotoPath: path));
    await _eventos.insert(
      CellEvent(
        celdaId: celda.id!,
        tipo: EventType.photo,
        fecha: DateTime.now(),
        nota: 'Foto de evidencia actualizada',
      ),
    );
    await refresh();
  }

  // ---------- Tests ----------

  Future<List<CellTest>> testsOf(int celdaId) => _tests.byCelda(celdaId);

  Future<List<CellEvent>> eventsOf(int celdaId) => _eventos.byCelda(celdaId);

  Future<int> testCount(int celdaId) => _tests.countByCelda(celdaId);

  /// Registra una medición: recalcula SoH/veredicto y actualiza la celda.
  Future<void> addTest(Celda celda, CellTest test) async {
    if (celda.id == null) return;

    final result = classifyByCapacity(
      measuredMah: test.capacidadMedidaMah,
      nominalMah: celda.capacidadNominalMah,
      thresholds: thresholds,
    );
    final conResultado = test.copyWith(
      celdaId: celda.id,
      sohPct: result.soh,
      veredicto: result.verdict,
    );

    final nuevaCelda = celda.copyWith(
      veredicto: result.verdict,
      sohPct: result.soh,
      estado: celda.estado.isFinal ? celda.estado : CellState.classified,
    );

    await _saveTest(celdaId: celda.id!, test: conResultado, celda: nuevaCelda);
    await refresh();
  }

  Future<void> _saveTest({
    required int celdaId,
    required CellTest test,
    required Celda celda,
  }) async {
    await _tests.insert(test.copyWith(celdaId: celdaId));
    await _celdas.update(celda.copyWith(id: celdaId));

    await _eventos.insert(
      CellEvent(
        celdaId: celdaId,
        tipo: EventType.tested,
        fecha: test.fecha,
        nota: test.sohPct == null
            ? 'Test registrado'
            : 'Test registrado — SoH ${formatSoh(test.sohPct)} '
                '(${test.veredicto?.code ?? '—'})',
      ),
    );

    if (celda.veredicto != null) {
      await _eventos.insert(
        CellEvent(
          celdaId: celdaId,
          tipo: EventType.stateChanged,
          estadoNuevo: celda.estado.name,
          fecha: DateTime.now(),
          nota: 'Clasificada como ${celda.veredicto!.code} '
              '(${formatSoh(celda.sohPct)})',
        ),
      );
    }
  }

  Future<void> deleteTest(CellTest test) async {
    if (test.id == null) return;
    await _tests.delete(test.id!);
    await refresh();
  }

  // ---------- Lotes ----------

  Future<int> addLote(Lote lote) async {
    final id = await _lotes.insert(lote);
    await refresh();
    return id;
  }

  Future<void> updateLote(Lote lote) async {
    await _lotes.update(lote);
    await refresh();
  }

  Future<void> deleteLote(Lote lote) async {
    if (lote.id == null) return;
    await _lotes.delete(lote.id!);
    await refresh();
  }

  /// Sugiere el siguiente código de lote (L-2026-09-A, -B, …).
  Future<String> suggestLoteCodigo() async {
    final now = DateTime.now();
    final base =
        'L-${now.year}-${now.month.toString().padLeft(2, '0')}';
    final existentes = (await _lotes.codigos()).toSet();
    for (var i = 0; i < 26; i++) {
      final candidato = '$base-${String.fromCharCode(65 + i)}';
      if (!existentes.contains(candidato)) return candidato;
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch % 1000}';
  }

  // ---------- Ajustes ----------

  Future<void> saveThresholds(Thresholds t) async {
    thresholds = t.sanitized();
    await _prefs.saveThresholds(thresholds);
    notifyListeners();
  }

  Future<void> saveRejectReasons(List<String> reasons) async {
    rejectReasons = reasons;
    await _prefs.saveRejectReasons(reasons);
    notifyListeners();
  }

  // ---------- Importación ----------

  /// Importa celdas (desde CSV). Omite códigos ya existentes.
  Future<ImportSummary> importCeldas(List<Celda> nuevas) async {
    var imported = 0;
    final skipped = <String>[];
    for (final c in nuevas) {
      if (await _celdas.existsCodigo(c.codigoInterno)) {
        skipped.add(c.codigoInterno);
        continue;
      }
      final id = await _celdas.insert(c);
      await _eventos.insert(
        CellEvent(
          celdaId: id,
          tipo: EventType.created,
          fecha: DateTime.now(),
          nota: 'Importada desde CSV',
        ),
      );
      imported++;
    }
    await refresh();
    return ImportSummary(imported: imported, skipped: skipped);
  }
}

/// Resumen de una importación.
class ImportSummary {
  const ImportSummary({required this.imported, required this.skipped});
  final int imported;
  final List<String> skipped;
}
