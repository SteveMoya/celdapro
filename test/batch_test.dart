import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:celdapro/core/batch_session.dart';
import 'package:celdapro/core/theme.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/celda_foto.dart';
import 'package:celdapro/features/tests/batch_test_screen.dart';
import 'package:celdapro/state/celda_controller.dart';

/// Celda de prueba.
Celda _celda(
  int id,
  String codigo, {
  double? nominal = 2500,
  double? soh,
  CellState estado = CellState.received,
}) =>
    Celda(
      id: id,
      codigoInterno: codigo,
      marca: 'Samsung',
      capacidadNominalMah: nominal,
      estado: estado,
      sohPct: soh,
      createdAt: DateTime(2026, 9, 20),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  group('BatchSession', () {
    test('solo incluye celdas sin medición', () {
      final pendientes = BatchSession.pendientesDe([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002', soh: 94),
        _celda(3, 'C-0003'),
      ]);

      expect(pendientes.map((c) => c.codigoInterno), ['C-0001', 'C-0003']);
    });

    test('ordena por código interno', () {
      final pendientes = BatchSession.pendientesDe([
        _celda(9, 'C-0010'),
        _celda(1, 'C-0002'),
        _celda(5, 'C-0007'),
      ]);

      expect(pendientes.map((c) => c.codigoInterno), [
        'C-0002',
        'C-0007',
        'C-0010',
      ]);
    });

    test('recorre la cola y cuenta las registradas', () {
      final s = BatchSession([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);

      expect(s.total, 2);
      expect(s.actual?.codigoInterno, 'C-0001');
      expect(s.progreso, 0);

      s.siguiente();
      expect(s.guardadas, 1);
      expect(s.actual?.codigoInterno, 'C-0002');
      expect(s.progreso, 0.5);
      expect(s.terminado, isFalse);

      s.siguiente();
      expect(s.terminado, isTrue);
      expect(s.actual, isNull);
      expect(s.progreso, 1);
      expect(s.restantes, 0);
    });

    test('saltar deja la celda como no medida', () {
      final s = BatchSession([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);

      s.saltar();

      expect(s.saltadas, 1);
      expect(s.guardadas, 0);
      expect(s.saltadasLista.single.codigoInterno, 'C-0001');
    });

    test('avanzar de más no rompe ni duplica', () {
      final s = BatchSession([_celda(1, 'C-0001')]);
      s.siguiente();
      s.siguiente();
      s.siguiente();

      expect(s.guardadas, 1);
      expect(s.terminado, isTrue);
    });

    test('retrocede a la anterior sin borrar lo registrado', () {
      final s = BatchSession([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);
      s.siguiente();
      s.anterior();

      expect(s.index, 0);
      expect(s.actual?.codigoInterno, 'C-0001');
      expect(s.guardadas, 1);
    });

    test('no retrocede más allá de la primera', () {
      final s = BatchSession([_celda(1, 'C-0001')]);
      s.anterior();
      expect(s.index, 0);
    });

    test('una sesión vacía está terminada', () {
      final s = BatchSession([]);
      expect(s.vacio, isTrue);
      expect(s.terminado, isTrue);
      expect(s.actual, isNull);
      expect(s.progreso, 1);
    });

    test('avisa de las celdas sin capacidad nominal', () {
      final s = BatchSession([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002', nominal: null),
      ]);

      expect(s.sinNominal.single.codigoInterno, 'C-0002');
    });

    test('el resumen cuenta lo registrado y lo saltado', () {
      final s = BatchSession([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
        _celda(3, 'C-0003'),
      ]);
      s.siguiente();
      s.saltar();

      expect(s.resumen, '1 de 3 registradas · 1 sin medir');
    });
  });

  group('CeldaFoto', () {
    test('viaja de ida y vuelta por la base de datos', () {
      final foto = CeldaFoto(
        id: 7,
        celdaId: 3,
        path: '/fotos/celda_3_1.jpg',
        etiqueta: PhotoTag.failure,
        fecha: DateTime(2026, 9, 20, 14, 30),
        nota: 'Bornes sulfatados',
      );

      final copia = CeldaFoto.fromMap(foto.toMap());

      expect(copia.id, 7);
      expect(copia.celdaId, 3);
      expect(copia.path, '/fotos/celda_3_1.jpg');
      expect(copia.etiqueta, PhotoTag.failure);
      expect(copia.fecha, DateTime(2026, 9, 20, 14, 30));
      expect(copia.nota, 'Bornes sulfatados');
    });

    test('sin id no manda la clave a la base de datos', () {
      final foto = CeldaFoto(
        celdaId: 1,
        path: '/fotos/a.jpg',
        fecha: DateTime(2026, 9, 20),
      );

      expect(foto.toMap().containsKey('id'), isFalse);
    });

    test('una etiqueta desconocida cae en evidencia', () {
      expect(PhotoTag.fromName('inventada'), PhotoTag.evidence);
      expect(PhotoTag.fromName(null), PhotoTag.evidence);
      expect(PhotoTag.fromName('before'), PhotoTag.before);
    });
  });

  group('Pantalla de test masivo', () {
    CeldaController fake(List<Celda> celdas) {
      final c = CeldaController();
      c.loading = false;
      c.celdas = celdas;
      return c;
    }

    Future<void> pump(
      WidgetTester tester,
      Widget child,
      CeldaController c,
    ) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: c,
          child: MaterialApp(
            theme: AppTheme.light(),
            locale: const Locale('es'),
            home: child,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    void phone(WidgetTester tester) {
      tester.view.physicalSize = const Size(1080, 2280);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
    }

    testWidgets('muestra el avance y la celda que toca medir',
        (tester) async {
      phone(tester);
      final c = fake([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
        _celda(3, 'C-0003'),
      ]);

      await pump(
        tester,
        BatchTestScreen(celdas: BatchSession.pendientesDe(c.celdas)),
        c,
      );

      expect(find.text('Celda 1 de 3'), findsOneWidget);
      expect(find.text('C-0001'), findsOneWidget);
      expect(find.text('2500 mAh'), findsOneWidget);
      expect(find.text('Guardar y siguiente'), findsOneWidget);
    });

    testWidgets('calcula el veredicto mientras se escribe', (tester) async {
      phone(tester);
      final c = fake([_celda(1, 'C-0001', nominal: 2500)]);

      await pump(
        tester,
        BatchTestScreen(celdas: BatchSession.pendientesDe(c.celdas)),
        c,
      );

      // 2300 de 2500 = 92 % → apta (A).
      await tester.enterText(find.byType(TextField).first, '2300');
      await tester.pump();

      expect(find.text('92.0 %'), findsOneWidget);
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('una medida baja se marca como rechazo', (tester) async {
      phone(tester);
      final c = fake([_celda(1, 'C-0001', nominal: 2500)]);

      await pump(
        tester,
        BatchTestScreen(celdas: BatchSession.pendientesDe(c.celdas)),
        c,
      );

      // 1200 de 2500 = 48 % → por debajo del 60 %: rechazo.
      await tester.enterText(find.byType(TextField).first, '1200');
      await tester.pump();

      expect(find.text('48.0 %'), findsOneWidget);
      expect(find.text('Rechazo'), findsOneWidget);
    });

    testWidgets('sin celdas pendientes lo dice en vez de fallar',
        (tester) async {
      phone(tester);
      await pump(tester, const BatchTestScreen(celdas: []), fake([]));

      expect(find.text('No hay celdas pendientes'), findsOneWidget);
      expect(find.text('Guardar y siguiente'), findsNothing);
    });

    testWidgets('no deja guardar sin escribir la medida', (tester) async {
      phone(tester);
      // Dos celdas para que el botón diga "siguiente" y no "terminar".
      final c = fake([
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);
      await pump(
        tester,
        BatchTestScreen(celdas: BatchSession.pendientesDe(c.celdas)),
        c,
      );

      await tester.tap(find.text('Guardar y siguiente'));
      await tester.pump();

      expect(find.text('Escribe la capacidad medida'), findsOneWidget);
    });

    testWidgets('la última celda cambia el botón a terminar', (tester) async {
      phone(tester);
      final c = fake([_celda(1, 'C-0001')]);
      await pump(
        tester,
        BatchTestScreen(celdas: BatchSession.pendientesDe(c.celdas)),
        c,
      );

      expect(find.text('Guardar y terminar'), findsOneWidget);
    });
  });
}
