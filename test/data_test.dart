import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/database_helper.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/celda_foto.dart';
import 'package:celdapro/data/models/cell_event.dart';
import 'package:celdapro/data/models/cell_test.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/data/preferences_store.dart';
import 'package:celdapro/data/repositories/celda_foto_repository.dart';
import 'package:celdapro/data/repositories/celda_repository.dart';
import 'package:celdapro/data/repositories/cell_event_repository.dart';
import 'package:celdapro/data/repositories/cell_test_repository.dart';
import 'package:celdapro/data/repositories/lote_repository.dart';

/// Pruebas de la capa de datos contra **SQLite de verdad** (en memoria).
///
/// Antes se probaba la app entera menos la base de datos, que es justo donde
/// vive el trabajo del taller: un fallo ahí se lleva el historial completo.
/// Aquí se ejercitan los repositorios, los filtros, los agregados y la
/// migración real.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CeldaRepository celdas;
  late LoteRepository lotes;
  late CellTestRepository tests;
  late CellEventRepository eventos;
  late CeldaFotoRepository fotos;
  late PreferencesStore prefs;

  setUp(() async {
    // Base nueva y vacía por cada prueba: ninguna depende de la anterior.
    // Se crea con el código de la app, así que el esquema es el real.
    db = await DatabaseHelper.abrirEn(inMemoryDatabasePath);
    DatabaseHelper.baseDePruebas = db;

    celdas = CeldaRepository();
    lotes = LoteRepository();
    tests = CellTestRepository();
    eventos = CellEventRepository();
    fotos = CeldaFotoRepository();
    prefs = PreferencesStore();
  });

  tearDown(() async {
    DatabaseHelper.baseDePruebas = null;
    await db.close();
  });

  /// Comprueba que una operación falla por código duplicado.
  ///
  /// Se mira el mensaje de SQLite en vez del tipo de excepción: lo que
  /// interesa verificar es que la **base** lo impide, no cómo se llama la
  /// excepción que devuelve el driver.
  Future<void> esperaDuplicado(Future<void> Function() accion) async {
    try {
      await accion();
      fail('La base debería haber rechazado el código duplicado');
    } catch (e) {
      expect('$e'.toUpperCase(), contains('UNIQUE'));
    }
  }

  Lote loteDePrueba({String codigo = 'L-2026-09-A'}) => Lote(
        codigo: codigo,
        proveedor: 'Provmotors',
        origen: 'Lote de laptops',
        fechaRecepcion: DateTime(2026, 9, 2),
      );

  Celda celdaDePrueba({
    required String codigo,
    int? loteId,
    String? marca = 'Samsung',
    String? modelo = '25R',
    double? nominal = 2500,
    CellState estado = CellState.received,
    Verdict? veredicto,
    double? soh,
    Chemistry quimica = Chemistry.liIon,
    String? ubicacion,
    String? foto,
  }) =>
      Celda(
        loteId: loteId,
        codigoInterno: codigo,
        marca: marca,
        modelo: modelo,
        quimica: quimica,
        capacidadNominalMah: nominal,
        voltajeNominal: 3.6,
        estado: estado,
        veredicto: veredicto,
        sohPct: soh,
        ubicacion: ubicacion,
        fotoPath: foto,
        createdAt: DateTime(2026, 9, 20),
      );

  group('Celdas: guardar y leer', () {
    test('una celda guardada vuelve con todos sus datos', () async {
      final id = await celdas.insert(celdaDePrueba(
        codigo: 'C-0001',
        marca: 'Molicel',
        modelo: 'P26A',
        nominal: 2600,
        estado: CellState.classified,
        veredicto: Verdict.a,
        soh: 93.5,
        quimica: Chemistry.lfp,
        ubicacion: 'Estante A1',
      ));

      final leida = await celdas.byId(id);

      expect(leida, isNotNull);
      expect(leida!.codigoInterno, 'C-0001');
      expect(leida.marca, 'Molicel');
      expect(leida.modelo, 'P26A');
      expect(leida.capacidadNominalMah, 2600);
      expect(leida.estado, CellState.classified);
      expect(leida.veredicto, Verdict.a);
      expect(leida.sohPct, 93.5);
      expect(leida.quimica, Chemistry.lfp);
      expect(leida.ubicacion, 'Estante A1');
      expect(leida.createdAt, DateTime(2026, 9, 20));
    });

    test('no se pueden repetir códigos internos', () async {
      await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      await esperaDuplicado(
        () => celdas.insert(celdaDePrueba(codigo: 'C-0001')),
      );
    });

    test('existeCodigo distingue el propio al editar', () async {
      final id = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      expect(await celdas.existsCodigo('C-0001'), isTrue);
      expect(await celdas.existsCodigo('C-0002'), isFalse);
      // Al editar la misma celda, su propio código no cuenta como repetido.
      expect(await celdas.existsCodigo('C-0001', exceptId: id), isFalse);
    });

    test('actualizar cambia los datos sin perder la fila', () async {
      final id = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      final original = (await celdas.byId(id))!;

      await celdas.update(original.copyWith(
        estado: CellState.rejected,
        veredicto: Verdict.reject,
        sohPct: 48,
      ));

      final leida = (await celdas.byId(id))!;
      expect(leida.estado, CellState.rejected);
      expect(leida.veredicto, Verdict.reject);
      expect(leida.sohPct, 48);
      expect(await celdas.total(), 1);
    });

    test('borrar quita la celda', () async {
      final id = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      await celdas.delete(id);

      expect(await celdas.byId(id), isNull);
      expect(await celdas.total(), 0);
    });
  });

  group('Celdas: filtros', () {
    setUp(() async {
      final loteA = await lotes.insert(loteDePrueba());
      final loteB = await lotes.insert(loteDePrueba(codigo: 'L-2026-09-B'));

      await celdas.insert(celdaDePrueba(
        codigo: 'C-0001',
        loteId: loteA,
        marca: 'Samsung',
        modelo: '25R',
        estado: CellState.classified,
        veredicto: Verdict.a,
        soh: 94,
      ));
      await celdas.insert(celdaDePrueba(
        codigo: 'C-0002',
        loteId: loteA,
        marca: 'LG',
        modelo: 'HG2',
        estado: CellState.classified,
        veredicto: Verdict.reject,
        soh: 55,
      ));
      await celdas.insert(celdaDePrueba(
        codigo: 'C-0003',
        loteId: loteB,
        marca: 'Molicel',
        modelo: 'P26A',
        estado: CellState.received,
      ));
    });

    test('sin filtro devuelve todo ordenado por código', () async {
      final todas = await celdas.all();
      expect(todas.map((c) => c.codigoInterno), ['C-0001', 'C-0002', 'C-0003']);
    });

    test('filtra por texto en código, marca o modelo', () async {
      expect((await celdas.all(filter: const CeldaFilter(texto: 'C-0002')))
          .single.codigoInterno, 'C-0002');
      expect((await celdas.all(filter: const CeldaFilter(texto: 'LG')))
          .single.codigoInterno, 'C-0002');
      expect((await celdas.all(filter: const CeldaFilter(texto: 'P26A')))
          .single.codigoInterno, 'C-0003');
      // No distingue mayúsculas de minúsculas.
      expect((await celdas.all(filter: const CeldaFilter(texto: 'p26a')))
          .single.codigoInterno, 'C-0003');
    });

    test('filtra por etapa y por veredicto', () async {
      expect(
        (await celdas.all(filter: const CeldaFilter(estado: CellState.received)))
            .single
            .codigoInterno,
        'C-0003',
      );
      expect(
        (await celdas.all(
                filter: const CeldaFilter(veredicto: Verdict.reject)))
            .single
            .codigoInterno,
        'C-0002',
      );
    });

    test('filtra por lote', () async {
      final delA = await celdas.byLote(1);
      expect(delA.map((c) => c.codigoInterno), ['C-0001', 'C-0002']);
      final delB = await celdas.byLote(2);
      expect(delB.map((c) => c.codigoInterno), ['C-0003']);
    });

    test('los filtros se combinan', () async {
      final r = await celdas.all(
        filter: const CeldaFilter(loteId: 1, estado: CellState.classified),
      );
      expect(r, hasLength(2));

      final mixto = await celdas.all(
        filter: const CeldaFilter(
          loteId: 1,
          estado: CellState.classified,
          veredicto: Verdict.a,
        ),
      );
      expect(mixto.single.codigoInterno, 'C-0001');
    });

    test('un filtro sin resultados devuelve una lista vacía, no todo', () async {
      final r = await celdas.all(filter: const CeldaFilter(texto: 'noexiste'));
      expect(r, isEmpty);
    });
  });

  group('Celdas: métricas agregadas', () {
    test('cuenta por etapa y por veredicto', () async {
      await celdas.insert(celdaDePrueba(
          codigo: 'C-0001',
          estado: CellState.classified,
          veredicto: Verdict.a,
          soh: 94));
      await celdas.insert(celdaDePrueba(
          codigo: 'C-0002',
          estado: CellState.classified,
          veredicto: Verdict.a,
          soh: 91));
      await celdas.insert(celdaDePrueba(
          codigo: 'C-0003',
          estado: CellState.rejected,
          veredicto: Verdict.reject,
          soh: 50));
      // Sin clasificar: no debe contar en el veredicto.
      await celdas.insert(celdaDePrueba(codigo: 'C-0004'));

      final porEstado = await celdas.countByEstado();
      expect(porEstado[CellState.classified], 2);
      expect(porEstado[CellState.rejected], 1);
      expect(porEstado[CellState.received], 1);

      final porVeredicto = await celdas.countByVeredicto();
      expect(porVeredicto[Verdict.a], 2);
      expect(porVeredicto[Verdict.reject], 1);
      // Las celdas sin veredicto no aparecen.
      expect(porVeredicto.values.fold<int>(0, (a, b) => a + b), 3);
    });

    test('el SoH promedio ignora las celdas sin medir', () async {
      await celdas.insert(celdaDePrueba(codigo: 'C-0001', soh: 90));
      await celdas.insert(celdaDePrueba(codigo: 'C-0002', soh: 80));
      await celdas.insert(celdaDePrueba(codigo: 'C-0003'));

      expect(await celdas.averageSoh(), 85.0);
    });

    test('sin celdas medidas no hay promedio (no es cero)', () async {
      await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      expect(await celdas.averageSoh(), isNull);
    });

    test('el total cuenta todas las celdas', () async {
      expect(await celdas.total(), 0);
      await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await celdas.insert(celdaDePrueba(codigo: 'C-0002'));
      expect(await celdas.total(), 2);
    });
  });

  group('Lotes', () {
    test('guarda y devuelve los lotes', () async {
      await lotes.insert(loteDePrueba());

      final todos = await lotes.all();
      expect(todos.single.codigo, 'L-2026-09-A');
      expect(todos.single.proveedor, 'Provmotors');
      expect(todos.single.fechaRecepcion, DateTime(2026, 9, 2));
    });

    test('los códigos de lote no se repiten', () async {
      await lotes.insert(loteDePrueba());
      await esperaDuplicado(() => lotes.insert(loteDePrueba()));
    });

    test('borrar un lote no borra sus celdas, las deja sin lote', () async {
      final loteId = await lotes.insert(loteDePrueba());
      final celdaId = await celdas.insert(celdaDePrueba(
        codigo: 'C-0001',
        loteId: loteId,
      ));

      await lotes.delete(loteId);

      final celda = await celdas.byId(celdaId);
      expect(celda, isNotNull, reason: 'la celda no debe desaparecer');
      expect(celda!.loteId, isNull);
    });

    test('codigos() lista los códigos existentes', () async {
      await lotes.insert(loteDePrueba());
      await lotes.insert(loteDePrueba(codigo: 'L-2026-09-B'));

      expect(await lotes.codigos(), containsAll(['L-2026-09-A', 'L-2026-09-B']));
    });
  });

  group('Tests de celdas', () {
    test('se guardan y se leen del más reciente al más antiguo', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      await tests.insert(CellTest(
        celdaId: celdaId,
        fecha: DateTime(2026, 9, 18),
        capacidadMedidaMah: 2300,
        sohPct: 92,
        veredicto: Verdict.a,
      ));
      await tests.insert(CellTest(
        celdaId: celdaId,
        fecha: DateTime(2026, 9, 19),
        capacidadMedidaMah: 2400,
        sohPct: 96,
        veredicto: Verdict.a,
        operador: 'Steve',
      ));

      final lista = await tests.byCelda(celdaId);
      expect(lista, hasLength(2));
      // La medición más nueva va primero: es la que interesa ver al abrir.
      expect(lista.first.fecha, DateTime(2026, 9, 19));
      expect(lista.first.capacidadMedidaMah, 2400);
      expect(lista.first.operador, 'Steve');
      expect(lista.last.fecha, DateTime(2026, 9, 18));
      expect(await tests.countByCelda(celdaId), 2);
    });

    test('lastByCelda devuelve la medición más reciente', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await tests.insert(CellTest(
        celdaId: celdaId,
        fecha: DateTime(2026, 9, 18),
        capacidadMedidaMah: 2300,
      ));
      await tests.insert(CellTest(
        celdaId: celdaId,
        fecha: DateTime(2026, 9, 20),
        capacidadMedidaMah: 2450,
      ));

      expect((await tests.lastByCelda(celdaId))!.capacidadMedidaMah, 2450);
    });

    test('borrar la celda se lleva sus mediciones', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await tests.insert(CellTest(
        celdaId: celdaId,
        fecha: DateTime(2026, 9, 18),
        capacidadMedidaMah: 2300,
      ));

      await celdas.delete(celdaId);

      expect(await tests.byCelda(celdaId), isEmpty);
    });
  });

  group('Historial (eventos)', () {
    test('el cambio de etapa queda registrado con el antes y el después',
        () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      await eventos.logStateChange(
        celdaId: celdaId,
        from: CellState.received.name,
        to: CellState.testing.name,
        nota: 'Cambio en bloque a En test',
      );

      final historial = await eventos.byCelda(celdaId);
      expect(historial, hasLength(1));
      expect(historial.single.tipo, EventType.stateChanged);
      expect(historial.single.estadoAnterior, 'received');
      expect(historial.single.estadoNuevo, 'testing');
      expect(historial.single.nota, contains('En test'));
    });

    test('los eventos se conservan al borrar la celda solo si tiene sentido',
        () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await eventos.insert(CellEvent(
        celdaId: celdaId,
        tipo: EventType.created,
        fecha: DateTime(2026, 9, 20),
      ));

      await celdas.delete(celdaId);

      // El historial de una celda que ya no existe no debe quedar huérfano.
      expect(await eventos.byCelda(celdaId), isEmpty);
    });
  });

  group('Fotos de la galería', () {
    test('varias fotos por celda, con su etiqueta, en orden', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));

      await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/a.jpg',
        etiqueta: PhotoTag.before,
        fecha: DateTime(2026, 9, 18),
      ));
      await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/b.jpg',
        etiqueta: PhotoTag.after,
        fecha: DateTime(2026, 9, 19),
      ));

      final lista = await fotos.byCelda(celdaId);
      expect(lista.map((f) => f.etiqueta), [PhotoTag.before, PhotoTag.after]);
      expect(lista.map((f) => f.path), ['/fotos/a.jpg', '/fotos/b.jpg']);
    });

    test('borrar la celda se lleva sus fotos', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/a.jpg',
        fecha: DateTime(2026, 9, 18),
      ));

      await celdas.delete(celdaId);

      expect(await fotos.byCelda(celdaId), isEmpty);
    });

    test('cuenta las fotos de cada celda de una sola consulta', () async {
      final a = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      final b = await celdas.insert(celdaDePrueba(codigo: 'C-0002'));
      for (var i = 0; i < 3; i++) {
        await fotos.insert(CeldaFoto(
          celdaId: a,
          path: '/fotos/a$i.jpg',
          fecha: DateTime(2026, 9, 18),
        ));
      }
      await fotos.insert(CeldaFoto(
        celdaId: b,
        path: '/fotos/b.jpg',
        fecha: DateTime(2026, 9, 18),
      ));

      final conteo = await fotos.countsByCelda();
      expect(conteo[a], 3);
      expect(conteo[b], 1);
    });

    test('deleteByCelda devuelve las rutas para poder borrar los archivos',
        () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/a.jpg',
        fecha: DateTime(2026, 9, 18),
      ));
      await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/b.jpg',
        fecha: DateTime(2026, 9, 18),
      ));

      final rutas = await fotos.deleteByCelda(celdaId);
      expect(rutas, containsAll(['/fotos/a.jpg', '/fotos/b.jpg']));
      expect(await fotos.byCelda(celdaId), isEmpty);
    });

    test('cambiar la etiqueta de una foto', () async {
      final celdaId = await celdas.insert(celdaDePrueba(codigo: 'C-0001'));
      final id = await fotos.insert(CeldaFoto(
        celdaId: celdaId,
        path: '/fotos/a.jpg',
        etiqueta: PhotoTag.evidence,
        fecha: DateTime(2026, 9, 18),
      ));

      await fotos.update((await fotos.byCelda(celdaId)).single
          .copyWith(etiqueta: PhotoTag.failure));

      expect((await fotos.byCelda(celdaId)).single.etiqueta, PhotoTag.failure);
      expect(id, greaterThan(0));
    });
  });

  group('Ajustes guardados', () {
    test('los umbrales se guardan y se leen igual', () async {
      const t = Thresholds(aMin: 92, bMin: 78, cMin: 62);
      await prefs.saveThresholds(t);

      final leidos = await prefs.loadThresholds();
      expect(leidos.aMin, 92);
      expect(leidos.bMin, 78);
      expect(leidos.cMin, 62);
    });

    test('sin guardar nada, los umbrales son los de la app', () async {
      final t = await prefs.loadThresholds();
      expect(t.aMin, 90);
      expect(t.bMin, 75);
      expect(t.cMin, 60);
    });

    test('los motivos de rechazo se guardan como lista', () async {
      await prefs.saveRejectReasons(['Hinchada', 'No retiene carga']);

      expect(await prefs.loadRejectReasons(),
          ['Hinchada', 'No retiene carga']);
    });

    test('el nombre del taller vacío se lee como nulo', () async {
      await prefs.saveTaller('Taller Moya');
      expect(await prefs.loadTaller(), 'Taller Moya');

      await prefs.saveTaller('   ');
      expect(await prefs.loadTaller(), isNull);
    });

    test('la licencia Pro se guarda y se puede borrar', () async {
      expect(await prefs.loadLicencia(), isNull);
      await prefs.saveLicencia('CPRO-TALL-ER01-C427');
      expect(await prefs.loadLicencia(), 'CPRO-TALL-ER01-C427');
      await prefs.saveLicencia(null);
      expect(await prefs.loadLicencia(), isNull);
    });

    test('la búsqueda automática de actualizaciones viene activada', () async {
      expect(await prefs.loadUpdateAutomatico(), isTrue);
      await prefs.saveUpdateAutomatico(false);
      expect(await prefs.loadUpdateAutomatico(), isFalse);
      await prefs.saveUpdateAutomatico(true);
      expect(await prefs.loadUpdateAutomatico(), isTrue);
    });

    test('la fecha del último respaldo sobrevive', () async {
      final f = DateTime(2026, 9, 20, 14, 30);
      await prefs.saveLastBackup(f);
      expect(await prefs.loadLastBackup(), f);
    });
  });

  group('Inventario grande: paginación y filtros por rango', () {
    /// Mete [n] celdas directamente en la base (por SQL, para que sea rápido).
    Future<void> sembrar(int n) async {
      final batch = db.batch();
      for (var i = 1; i <= n; i++) {
        final medida = i % 4 == 0 ? null : (100 - (i % 40)).toDouble();
        batch.insert('celdas', {
          'codigo_interno': 'C-${i.toString().padLeft(5, '0')}',
          'marca': i.isEven ? 'Samsung' : 'LG',
          'quimica': 'liIon',
          'capacidad_nominal_mah': 2000.0 + (i % 30) * 100,
          'estado': 'received',
          'soh_pct': medida,
          'created_at': 1000 + i,
        });
      }
      await batch.commit(noResult: true);
    }

    test('la primera página trae solo el tamaño pedido', () async {
      await sembrar(250);

      final primera = await celdas.pagina(limite: 100);

      expect(primera, hasLength(100));
      expect(await celdas.contar(), 250);
    });

    test('las páginas no repiten ni se saltan celdas', () async {
      await sembrar(250);

      final todas = <String>[];
      for (var desplazamiento = 0;
          desplazamiento < 250;
          desplazamiento += 100) {
        final pagina = await celdas.pagina(
          limite: 100,
          desplazamiento: desplazamiento,
        );
        todas.addAll(pagina.map((c) => c.codigoInterno));
      }

      expect(todas, hasLength(250));
      expect(todas.toSet(), hasLength(250), reason: 'no debe repetir ninguna');
      expect(todas.first, 'C-00001');
      expect(todas.last, 'C-00250');
    });

    test('contar respeta el filtro, no solo el total', () async {
      await sembrar(100);

      final samsung = await celdas.contar(
        filter: const CeldaFilter(texto: 'Samsung'),
      );
      expect(samsung, 50);
      expect(await celdas.contar(), 100);
    });

    test('sinMedir trae solo las celdas sin medición', () async {
      await sembrar(100);

      final pendientes = await celdas.sinMedir();

      // En el sembrado, una de cada cuatro queda sin medir.
      expect(pendientes, hasLength(25));
      expect(pendientes.every((c) => c.sohPct == null), isTrue);
    });

    test('sinMedir respeta el filtro de texto', () async {
      await sembrar(100);

      // En el sembrado quedan sin medir las pares (i % 4 == 0), que son las
      // Samsung; las LG (impares) siempre llevan medición.
      final pendientes = await celdas.sinMedir(
        filter: const CeldaFilter(texto: 'Samsung'),
      );
      expect(pendientes, hasLength(25));

      final ninguna = await celdas.sinMedir(
        filter: const CeldaFilter(texto: 'LG'),
      );
      expect(ninguna, isEmpty);

      expect(pendientes.every((c) => c.marca == 'Samsung'), isTrue);
      expect(pendientes.every((c) => c.sohPct == null), isTrue);
    });

    test('filtra por rango de SoH', () async {
      await celdas.insert(celdaDePrueba(codigo: 'C-0001', soh: 95));
      await celdas.insert(celdaDePrueba(codigo: 'C-0002', soh: 80));
      await celdas.insert(celdaDePrueba(codigo: 'C-0003', soh: 55));
      await celdas.insert(celdaDePrueba(codigo: 'C-0004'));

      final buenas = await celdas.all(filter: const CeldaFilter(sohMin: 75));
      expect(buenas.map((c) => c.codigoInterno), ['C-0001', 'C-0002']);

      final mediocres = await celdas.all(
        filter: const CeldaFilter(sohMin: 60, sohMax: 90),
      );
      expect(mediocres.map((c) => c.codigoInterno), ['C-0002']);

      // Un rango de SoH deja fuera las celdas sin medir.
      final todas = await celdas.all(filter: const CeldaFilter(sohMax: 100));
      expect(todas.map((c) => c.codigoInterno), ['C-0001', 'C-0002', 'C-0003']);
    });

    test('filtra por rango de capacidad nominal', () async {
      await celdas.insert(celdaDePrueba(codigo: 'C-0001', nominal: 2000));
      await celdas.insert(celdaDePrueba(codigo: 'C-0002', nominal: 2600));
      await celdas.insert(celdaDePrueba(codigo: 'C-0003', nominal: 3500));

      final medianas = await celdas.all(
        filter: const CeldaFilter(capacidadMin: 2500, capacidadMax: 3000),
      );
      expect(medianas.single.codigoInterno, 'C-0002');
    });

    test('los rangos se combinan con el resto de filtros', () async {
      final loteId = await lotes.insert(loteDePrueba());
      await celdas.insert(celdaDePrueba(
          codigo: 'C-0001', loteId: loteId, soh: 95, veredicto: Verdict.a));
      await celdas.insert(celdaDePrueba(
          codigo: 'C-0002', loteId: loteId, soh: 62, veredicto: Verdict.c));

      final r = await celdas.all(
        filter: CeldaFilter(loteId: loteId, sohMin: 90, veredicto: Verdict.a),
      );
      expect(r.single.codigoInterno, 'C-0001');
    });

    test('5 000 celdas se abren en menos de un segundo', () async {
      await sembrar(5000);

      final cronometro = Stopwatch()..start();
      // Lo que hace la app al abrir el inventario.
      final primera = await celdas.pagina(limite: 100);
      final totalFiltrado = await celdas.contar();
      final pendientes = await celdas.sinMedir();
      cronometro.stop();

      expect(primera, hasLength(100));
      expect(totalFiltrado, 5000);
      expect(pendientes, hasLength(1250));
      // El criterio de aceptación del plan: menos de 1 segundo.
      expect(
        cronometro.elapsedMilliseconds,
        lessThan(1000),
        reason: 'abrir el inventario con 5 000 celdas tardó '
            '${cronometro.elapsedMilliseconds} ms',
      );
    });
  });

  group('Migración de la base de datos', () {
    /// Crea un archivo con el esquema **viejo (v2)** y datos, como lo tendría
    /// un teléfono que viene de una versión anterior de la app.
    Future<String> baseV2ConDatos() async {
      final ruta =
          '${Directory.systemTemp.path}/celdapro-v2-'
          '${DateTime.now().microsecondsSinceEpoch}.db';
      final vieja = await databaseFactory.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 2),
      );
      await vieja.execute('PRAGMA foreign_keys = ON');
      // Esquema v2 (sin la tabla de fotos).
      await vieja.execute('''
        CREATE TABLE lotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT NOT NULL,
          proveedor TEXT, origen TEXT, fecha_recepcion INTEGER NOT NULL,
          notas TEXT)''');
      await vieja.execute('''
        CREATE TABLE celdas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lote_id INTEGER REFERENCES lotes(id) ON DELETE SET NULL,
          codigo_interno TEXT NOT NULL UNIQUE, qr TEXT, marca TEXT, modelo TEXT,
          quimica TEXT NOT NULL, capacidad_nominal_mah REAL,
          voltaje_nominal REAL, fecha_fabricacion INTEGER, estado TEXT NOT NULL,
          veredicto TEXT, soh_pct REAL, ubicacion TEXT, foto_path TEXT,
          notas TEXT, catalog_ref TEXT, ir_nominal_mohm REAL,
          created_at INTEGER NOT NULL)''');
      await vieja.execute('''
        CREATE TABLE tests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
          fecha INTEGER NOT NULL, capacidad_medida_mah REAL)''');
      await vieja.execute('''
        CREATE TABLE eventos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
          tipo TEXT NOT NULL, fecha INTEGER NOT NULL)''');
      await vieja.execute('''
        CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');

      // Datos: dos celdas, una con foto y una medición.
      await vieja.insert('celdas', {
        'codigo_interno': 'C-0001',
        'marca': 'Samsung',
        'quimica': 'liIon',
        'estado': 'classified',
        'veredicto': 'a',
        'soh_pct': 94.0,
        'foto_path': '/fotos/celda_1_aaa.jpg',
        'created_at': 1000,
      });
      await vieja.insert('celdas', {
        'codigo_interno': 'C-0002',
        'marca': 'LG',
        'quimica': 'liIon',
        'estado': 'received',
        'created_at': 2000,
      });
      await vieja.insert('tests', {
        'celda_id': 1,
        'fecha': 1500,
        'capacidad_medida_mah': 2350.0,
      });
      await vieja.insert('prefs', {'key': 'nombre_taller', 'value': 'Mi taller'});
      await vieja.close();
      return ruta;
    }

    test('una base v2 se migra sin perder nada', () async {
      final ruta = await baseV2ConDatos();

      // Se abre con el código de la app: corre la migración de verdad.
      final migrada = await DatabaseHelper.abrirEn(ruta);
      DatabaseHelper.baseDePruebas = migrada;

      // Los datos siguen ahí.
      expect(await celdas.total(), 2);
      final c1 = (await celdas.all()).first;
      expect(c1.codigoInterno, 'C-0001');
      expect(c1.sohPct, 94.0);
      expect(c1.veredicto, Verdict.a);
      expect(await prefs.loadTaller(), 'Mi taller');
      expect(await tests.byCelda(1), hasLength(1));

      // Y la foto que ya existía aparece en la galería, como portada.
      final galeria = await fotos.byCelda(1);
      expect(galeria, hasLength(1));
      expect(galeria.single.path, '/fotos/celda_1_aaa.jpg');
      expect(galeria.single.etiqueta, PhotoTag.evidence);
      // La celda sin foto no inventa ninguna.
      expect(await fotos.byCelda(2), isEmpty);

      // Se puede seguir trabajando después de migrar.
      final id = await celdas.insert(celdaDePrueba(codigo: 'C-0003'));
      expect(await celdas.total(), 3);
      await fotos.insert(CeldaFoto(
        celdaId: id,
        path: '/fotos/nueva.jpg',
        fecha: DateTime(2026, 9, 20),
      ));
      expect(await fotos.byCelda(id), hasLength(1));

      DatabaseHelper.baseDePruebas = null;
      await migrada.close();
      File(ruta).deleteSync();
    });

    test('una base nueva se crea directamente con el esquema actual', () async {
      final ruta = '${Directory.systemTemp.path}/celdapro-nueva-'
          '${DateTime.now().microsecondsSinceEpoch}.db';

      final nueva = await DatabaseHelper.abrirEn(ruta);
      DatabaseHelper.baseDePruebas = nueva;

      // La tabla de fotos existe y se puede usar desde el primer momento.
      expect(await fotos.countsByCelda(), isEmpty);

      final tablas = await nueva.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final nombres = tablas.map((t) => t['name']).toList();
      expect(
        nombres,
        containsAll([
          DatabaseHelper.tableCeldas,
          DatabaseHelper.tableLotes,
          DatabaseHelper.tableTests,
          DatabaseHelper.tableEventos,
          DatabaseHelper.tableFotos,
          DatabaseHelper.tablePrefs,
        ]),
      );

      DatabaseHelper.baseDePruebas = null;
      await nueva.close();
      File(ruta).deleteSync();
    });

    test('los códigos de lote repetidos se renombran al migrar', () async {
      // Una base v3 podía tener dos lotes con el mismo código (nada lo
      // impedía). La v4 exige unicidad: los repetidos se renombran para no
      // perder ninguno.
      final ruta = '${Directory.systemTemp.path}/celdapro-v3-'
          '${DateTime.now().microsecondsSinceEpoch}.db';
      final vieja = await databaseFactory.openDatabase(
        ruta,
        options: OpenDatabaseOptions(version: 3),
      );
      await vieja.execute('''
        CREATE TABLE lotes (
          id INTEGER PRIMARY KEY AUTOINCREMENT, codigo TEXT NOT NULL,
          proveedor TEXT, origen TEXT, fecha_recepcion INTEGER NOT NULL,
          notas TEXT)''');
      await vieja.execute('''
        CREATE TABLE celdas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lote_id INTEGER REFERENCES lotes(id) ON DELETE SET NULL,
          codigo_interno TEXT NOT NULL UNIQUE, qr TEXT, marca TEXT, modelo TEXT,
          quimica TEXT NOT NULL, capacidad_nominal_mah REAL,
          voltaje_nominal REAL, fecha_fabricacion INTEGER, estado TEXT NOT NULL,
          veredicto TEXT, soh_pct REAL, ubicacion TEXT, foto_path TEXT,
          notas TEXT, catalog_ref TEXT, ir_nominal_mohm REAL,
          created_at INTEGER NOT NULL)''');
      await vieja.execute('''
        CREATE TABLE celda_fotos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
          path TEXT NOT NULL, etiqueta TEXT NOT NULL, fecha INTEGER NOT NULL,
          nota TEXT)''');
      await vieja.execute('''
        CREATE TABLE tests (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
          fecha INTEGER NOT NULL, capacidad_medida_mah REAL)''');
      await vieja.execute('''
        CREATE TABLE eventos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          celda_id INTEGER NOT NULL REFERENCES celdas(id) ON DELETE CASCADE,
          tipo TEXT NOT NULL, fecha INTEGER NOT NULL)''');
      await vieja.execute('''
        CREATE TABLE prefs (key TEXT PRIMARY KEY, value TEXT NOT NULL)''');

      // Tres lotes: dos chocan en el código y uno es distinto.
      for (final codigo in ['L-2026-09-A', 'L-2026-09-A', 'L-2026-09-B']) {
        await vieja.insert('lotes', {
          'codigo': codigo,
          'fecha_recepcion': 1000,
        });
      }
      await vieja.close();

      final migrada = await DatabaseHelper.abrirEn(ruta);
      DatabaseHelper.baseDePruebas = migrada;

      final todos = await lotes.all();
      final codigos = todos.map((l) => l.codigo).toList()..sort();
      // Ninguno se pierde y ninguno se repite.
      expect(todos, hasLength(3));
      expect(codigos, ['L-2026-09-A', 'L-2026-09-A-2', 'L-2026-09-B']);

      // Y a partir de ahora la base rechaza los repetidos.
      await esperaDuplicado(() => lotes.insert(loteDePrueba()));

      DatabaseHelper.baseDePruebas = null;
      await migrada.close();
      File(ruta).deleteSync();
    });
  });
}
