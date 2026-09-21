import 'package:flutter/foundation.dart';

import '../core/agrupacion.dart';
import '../core/classification.dart';
import '../core/pro_license.dart';
import '../data/models/celda.dart';
import '../data/models/celda_foto.dart';
import '../data/models/cell_event.dart';
import '../data/models/cell_test.dart';
import '../data/models/lote.dart';
import '../data/preferences_store.dart';
import '../data/repositories/celda_foto_repository.dart';
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
    CeldaFotoRepository? fotos,
    PreferencesStore? prefs,
    PhotoService photoService = const PhotoService(),
  })  : _celdas = celdas ?? CeldaRepository(),
        _lotes = lotes ?? LoteRepository(),
        _tests = tests ?? CellTestRepository(),
        _eventos = eventos ?? CellEventRepository(),
        _fotos = fotos ?? CeldaFotoRepository(),
        _prefs = prefs ?? PreferencesStore(),
        _photos = photoService;

  final CeldaRepository _celdas;
  final LoteRepository _lotes;
  final CellTestRepository _tests;
  final CellEventRepository _eventos;
  final CeldaFotoRepository _fotos;
  final PreferencesStore _prefs;
  final PhotoService _photos;

  List<Celda> celdas = const [];
  List<Lote> lotes = const [];
  bool loading = true;
  CeldaFilter filter = const CeldaFilter();

  /// Cuántas celdas se cargan de una vez al abrir el inventario.
  ///
  /// Con miles de celdas, traerlas todas al abrir hace que la app tarde y
  /// gaste memoria: se cargan por tandas y se piden más al bajar por la lista.
  static const tamanoPagina = 100;

  /// Cuántas celdas cumplen el filtro actual en total (no solo las cargadas).
  int totalFiltrado = 0;

  /// ¿Quedan celdas por traer con el filtro actual?
  bool get hayMas => celdas.length < totalFiltrado;

  /// ¿Se está trayendo otra tanda? (para no pedir dos veces la misma)
  bool cargandoMas = false;

  /// Celdas sin medición que cumplen el filtro (contadas en la base).
  int pendientesDeMedir = 0;

  Thresholds thresholds = const Thresholds();
  List<String> rejectReasons = PreferencesStore.defaultRejectReasons;

  Map<CellState, int> countsByEstado = const {};
  Map<Verdict, int> countsByVeredicto = const {};
  double? avgSoh;
  int total = 0;

  /// Fecha del último respaldo (null si nunca se ha hecho uno).
  DateTime? ultimoRespaldo;

  /// Nombre del taller: encabeza las etiquetas y los informes.
  ///
  /// Es una función **Pro**: sin licencia activa queda en null y los informes
  /// salen igual, con la marca de CeldaPro.
  String? nombreTaller;

  /// Código de licencia Pro guardado (null si no hay).
  String? licencia;

  /// Ruta del logo del taller (solo Pro).
  String? logoTaller;

  /// ¿Buscar actualizaciones sola al abrir la app?
  bool updateAutomatico = true;

  /// Tolerancias con las que se agrupan las celdas para armar packs.
  ToleranciasAgrupacion tolerancias = const ToleranciasAgrupacion();

  /// Filtros del inventario guardados con nombre (atajos).
  List<FiltroGuardado> filtrosGuardados = const [];

  /// ¿Está activada la versión Pro? Se comprueba el código sin conexión.
  bool get esPro => ProLicense.esCodigoValido(licencia);

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
    nombreTaller = await _prefs.loadTaller();
    licencia = await _prefs.loadLicencia();
    logoTaller = await _prefs.loadLogoTaller();
    updateAutomatico = await _prefs.loadUpdateAutomatico();
    tolerancias = await _prefs.loadTolerancias();
    filtrosGuardados = await _prefs.loadFiltrosGuardados();
    await refresh();
  }

  Future<void> refresh() async {
    loading = true;
    notifyListeners();

    celdas = await _celdas.pagina(
      filter: filter,
      limite: tamanoPagina,
    );
    totalFiltrado = await _celdas.contar(filter: filter);
    pendientesDeMedir = (await _celdas.sinMedir(filter: filter)).length;

    lotes = await _lotes.all();
    countsByEstado = await _celdas.countByEstado();
    countsByVeredicto = await _celdas.countByVeredicto();
    avgSoh = await _celdas.averageSoh();
    total = await _celdas.total();

    loading = false;
    notifyListeners();
  }

  /// Trae la siguiente tanda de celdas (al llegar al final de la lista).
  ///
  /// Devuelve cuántas añadió. No hace nada si ya está cargando o si no quedan.
  Future<int> cargarMas() async {
    if (loading || cargandoMas || !hayMas) return 0;
    cargandoMas = true;
    notifyListeners();
    try {
      final siguiente = await _celdas.pagina(
        filter: filter,
        limite: tamanoPagina,
        desplazamiento: celdas.length,
      );
      celdas = [...celdas, ...siguiente];
      return siguiente.length;
    } finally {
      cargandoMas = false;
      notifyListeners();
    }
  }

  /// Todas las celdas que aún no tienen medición con el filtro actual.
  ///
  /// Se consulta la base en vez de la lista cargada: con paginación, la lista
  /// en memoria es solo una parte del inventario y el registro en serie debe
  /// recorrer **todas** las pendientes, no solo las visibles.
  Future<List<Celda>> celdasSinMedir() => _celdas.sinMedir(filter: filter);

  Future<void> setFilter(CeldaFilter f) async {
    filter = f;
    await refresh();
  }

  // ---------- Filtros guardados ----------

  /// Guarda el filtro activo con un nombre, para volver a aplicarlo luego.
  ///
  /// Si ya había uno con ese nombre se reemplaza: el taller espera que
  /// «Samsung 25R» sea uno, no que se vayan acumulando repetidos.
  Future<void> guardarFiltroActual(String nombre) async {
    final n = nombre.trim();
    if (n.isEmpty) return;

    final lista = [...filtrosGuardados]
      ..removeWhere((f) => f.nombre.toLowerCase() == n.toLowerCase());
    lista.insert(0, FiltroGuardado(nombre: n, filtro: filter));

    filtrosGuardados =
        lista.take(maxFiltrosGuardados).toList(growable: false);
    await _prefs.saveFiltrosGuardados(filtrosGuardados);
    notifyListeners();
  }

  Future<void> borrarFiltroGuardado(String nombre) async {
    filtrosGuardados = filtrosGuardados
        .where((f) => f.nombre != nombre)
        .toList(growable: false);
    await _prefs.saveFiltrosGuardados(filtrosGuardados);
    notifyListeners();
  }

  /// Aplica un filtro guardado y recarga el inventario.
  Future<void> aplicarFiltroGuardado(FiltroGuardado f) => setFilter(f.filtro);

  // ---------- Agrupación ----------

  /// Cambia las tolerancias de agrupación y las deja guardadas.
  Future<void> setTolerancias(ToleranciasAgrupacion t) async {
    tolerancias = t.sanitized();
    await _prefs.saveTolerancias(tolerancias);
    notifyListeners();
  }

  /// Agrupa por similitud las celdas que cumplen [filtro].
  ///
  /// Trae **todas** las celdas que cumplen el filtro (no solo la página
  /// cargada): agrupar sobre una parte daría grupos incompletos. Usa el último
  /// test de cada celda, en una sola consulta.
  Future<ResultadoAgrupacion> agruparCeldas({CeldaFilter? filtro}) async {
    final lista = await _celdas.all(filter: filtro ?? filter);
    final ultimos = await _tests.ultimosPorCelda();
    final medidas = [
      for (final c in lista)
        CeldaMedida.de(c, c.id == null ? null : ultimos[c.id!]),
    ];
    return agruparConMotivos(celdas: medidas, tolerancias: tolerancias);
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

  /// Busca una celda por su código en la base, no en la lista cargada.
  ///
  /// El inventario está paginado: la celda escaneada puede estar más allá de
  /// la primera tanda, o fuera del filtro activo. Buscarla en memoria daría
  /// «no encontrada» y ofrecería dar de alta una celda que ya existe.
  Future<Celda?> celdaPorCodigo(String codigo) => _celdas.byCodigo(codigo);

  /// Todos los códigos del inventario, para proponer parecidos si el OCR falla.
  Future<List<String>> todosLosCodigos() => _celdas.codigos();

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
    // Todas las fotos de la galería, no solo la portada.
    final rutas = await _fotos.deleteByCelda(celda.id!);
    for (final r in rutas) {
      await _photos.delete(r);
    }
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

  // ---------- Acciones en bloque ----------

  /// Cambia la etapa de varias celdas de una vez.
  ///
  /// Cada celda registra su propio evento: el cambio en masa no puede borrar
  /// la trazabilidad, que es lo que hace auditable el taller. Se recarga el
  /// inventario **una sola vez** al final en vez de por celda.
  ///
  /// Devuelve cuántas celdas cambiaron de verdad (las que ya estaban en esa
  /// etapa se omiten, para no ensuciar el historial).
  Future<int> cambiarEstadoEnBloque(
    List<Celda> celdas,
    CellState nuevo, {
    String? nota,
  }) async {
    var cambiadas = 0;
    for (final celda in celdas) {
      if (celda.id == null || celda.estado == nuevo) continue;
      await _celdas.update(celda.copyWith(estado: nuevo));
      await _eventos.logStateChange(
        celdaId: celda.id!,
        from: celda.estado.name,
        to: nuevo.name,
        nota: nota ?? 'Cambio en bloque',
      );
      cambiadas++;
    }
    if (cambiadas > 0) await refresh();
    return cambiadas;
  }

  /// Asigna (o borra, con null) la ubicación de varias celdas.
  Future<int> asignarUbicacionEnBloque(
    List<Celda> celdas,
    String? ubicacion,
  ) async {
    final valor =
        (ubicacion ?? '').trim().isEmpty ? null : ubicacion!.trim();
    var cambiadas = 0;
    for (final celda in celdas) {
      if (celda.id == null || celda.ubicacion == valor) continue;
      await _celdas.update(celda.copyWith(ubicacion: valor));
      await _eventos.insert(
        CellEvent(
          celdaId: celda.id!,
          tipo: EventType.edited,
          fecha: DateTime.now(),
          nota: valor == null
              ? 'Ubicación quitada (en bloque)'
              : 'Ubicación «$valor» (en bloque)',
        ),
      );
      cambiadas++;
    }
    if (cambiadas > 0) await refresh();
    return cambiadas;
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

  // ---------- Fotos (galería) ----------

  Future<List<CeldaFoto>> fotosOf(int celdaId) => _fotos.byCelda(celdaId);

  /// Cuántas fotos tiene cada celda, de una sola consulta (para las listas).
  Future<Map<int, int>> fotosPorCelda() => _fotos.countsByCelda();

  /// Añade una foto a la galería de la celda.
  ///
  /// La primera foto pasa a ser la portada (`foto_path`), que es la que usan
  /// las etiquetas, los informes y las listas.
  Future<void> addFoto(
    Celda celda,
    String path, {
    PhotoTag etiqueta = PhotoTag.evidence,
    String? nota,
  }) async {
    if (celda.id == null) return;
    await _fotos.insert(
      CeldaFoto(
        celdaId: celda.id!,
        path: path,
        etiqueta: etiqueta,
        fecha: DateTime.now(),
        nota: nota,
      ),
    );

    if (celda.fotoPath == null || celda.fotoPath!.isEmpty) {
      await _celdas.update(celda.copyWith(fotoPath: path));
    }

    await _eventos.insert(
      CellEvent(
        celdaId: celda.id!,
        tipo: EventType.photo,
        fecha: DateTime.now(),
        nota: 'Foto añadida (${etiqueta.label})',
      ),
    );
    await refresh();
  }

  /// Quita una foto de la galería y borra el archivo.
  ///
  /// Si era la portada, la sustituye la siguiente foto que quede.
  Future<void> removeFoto(Celda celda, CeldaFoto foto) async {
    if (celda.id == null || foto.id == null) return;
    await _fotos.delete(foto.id!);

    if (celda.fotoPath == foto.path) {
      final restantes = await _fotos.byCelda(celda.id!);
      await _celdas.update(
        celda.copyWith(fotoPath: restantes.isEmpty ? '' : restantes.first.path),
      );
    }

    await _photos.delete(foto.path);
    await refresh();
  }

  /// Cambia la etiqueta de una foto de la galería.
  Future<void> setFotoEtiqueta(CeldaFoto foto, PhotoTag etiqueta) async {
    if (foto.id == null) return;
    await _fotos.update(foto.copyWith(etiqueta: etiqueta));
    await refresh();
  }

  // ---------- Duplicar ----------

  /// Copia una celda con un código nuevo, para casos repetidos.
  ///
  /// Copia los datos técnicos pero **no** el historial: la copia nace
  /// recepcionada, sin mediciones, sin veredicto y sin fotos.
  Future<int> duplicarCelda(Celda celda) async {
    final codigo = await suggestCodigo();
    final copia = Celda(
      loteId: celda.loteId,
      codigoInterno: codigo,
      marca: celda.marca,
      modelo: celda.modelo,
      quimica: celda.quimica,
      capacidadNominalMah: celda.capacidadNominalMah,
      voltajeNominal: celda.voltajeNominal,
      fechaFabricacion: celda.fechaFabricacion,
      estado: CellState.received,
      ubicacion: celda.ubicacion,
      notas: celda.notas,
      catalogRef: celda.catalogRef,
      irNominalMohm: celda.irNominalMohm,
      createdAt: DateTime.now(),
    );

    final id = await _celdas.insert(copia);
    await _eventos.insert(
      CellEvent(
        celdaId: id,
        tipo: EventType.created,
        estadoNuevo: CellState.received.name,
        fecha: DateTime.now(),
        nota: 'Copia de ${celda.codigoInterno}',
      ),
    );
    await refresh();
    return id;
  }

  // ---------- Tests ----------

  Future<List<CellTest>> testsOf(int celdaId) => _tests.byCelda(celdaId);

  Future<List<CellEvent>> eventsOf(int celdaId) => _eventos.byCelda(celdaId);

  Future<int> testCount(int celdaId) => _tests.countByCelda(celdaId);

  /// Registra una medición: recalcula SoH/veredicto y actualiza la celda.
  Future<void> addTest(Celda celda, CellTest test) async {
    await addTestRapido(celda, test);
    await refresh();
  }

  /// Registra una medición **sin recargar** el inventario.
  ///
  /// El modo masivo guarda decenas de celdas seguidas: recargar todo el
  /// inventario después de cada una lo volvería lento y haría parpadear la
  /// pantalla. Quien la use llama a [refresh] al cerrar la sesión.
  Future<CellTest> addTestRapido(Celda celda, CellTest test) async {
    if (celda.id == null) return test;

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
    return conResultado;
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

  /// ¿Existe ya un lote con este código? (para avisar antes de guardar)
  Future<bool> loteCodigoExiste(String codigo, {int? exceptId}) =>
      _lotes.existsCodigo(codigo, exceptId: exceptId);

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

  /// Guarda el nombre del taller (encabeza etiquetas e informes). Solo Pro.
  Future<void> setNombreTaller(String? nombre) async {
    await _prefs.saveTaller(nombre);
    nombreTaller = await _prefs.loadTaller();
    notifyListeners();
  }

  /// Activa la versión Pro con un código de licencia.
  ///
  /// Devuelve false si el código no es válido: en ese caso no se guarda nada.
  Future<bool> activarPro(String codigo) async {
    final limpio = ProLicense.normalizar(codigo);
    if (!ProLicense.esCodigoValido(limpio)) return false;
    await _prefs.saveLicencia(limpio);
    licencia = limpio;
    notifyListeners();
    return true;
  }

  /// Desactiva la versión Pro.
  ///
  /// El nombre y el logo del taller se conservan por si vuelve a activarla,
  /// pero dejan de utilizarse en los informes.
  Future<void> desactivarPro() async {
    await _prefs.saveLicencia(null);
    licencia = null;
    notifyListeners();
  }

  /// Guarda el logo del taller (versión Pro).
  Future<void> setLogoTaller(String path) async {
    await _photos.delete(logoTaller);
    await _prefs.saveLogoTaller(path);
    logoTaller = path;
    notifyListeners();
  }

  /// Quita el logo del taller.
  Future<void> quitarLogoTaller() async {
    await _photos.delete(logoTaller);
    await _prefs.saveLogoTaller(null);
    logoTaller = null;
    notifyListeners();
  }

  /// ¿Buscar actualizaciones sola al abrir la app?
  Future<void> setUpdateAutomatico(bool activo) async {
    await _prefs.saveUpdateAutomatico(activo);
    updateAutomatico = activo;
    notifyListeners();
  }

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
