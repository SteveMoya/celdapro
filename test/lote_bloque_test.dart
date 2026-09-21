import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:celdapro/core/theme.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/features/lotes/lote_celdas_screen.dart';
import 'package:celdapro/state/celda_controller.dart';

/// Controlador de prueba que anota lo que se le pide sin tocar la base de
/// datos: así se prueba la pantalla (selección, acciones) por separado de
/// SQLite, que en los tests de widget no está disponible.
class _ControllerFalso extends CeldaController {
  _ControllerFalso({required this.celdasFalsas});

  final List<Celda> celdasFalsas;

  /// Llamadas registradas: (etapa destino, códigos de las celdas).
  final List<(CellState, List<String>)> llamadasEtapa = [];
  final List<(String?, List<String>)> llamadasUbicacion = [];

  @override
  List<Celda> get celdas => celdasFalsas;

  @override
  Future<int> cambiarEstadoEnBloque(
    List<Celda> celdas,
    CellState nuevo, {
    String? nota,
  }) async {
    llamadasEtapa.add((nuevo, celdas.map((c) => c.codigoInterno).toList()));
    // Se refleja el cambio para que la pantalla no muestre datos viejos.
    for (var i = 0; i < celdasFalsas.length; i++) {
      if (celdas.any((c) => c.id == celdasFalsas[i].id)) {
        celdasFalsas[i] = celdasFalsas[i].copyWith(estado: nuevo);
      }
    }
    return celdas.length;
  }

  @override
  Future<int> asignarUbicacionEnBloque(
    List<Celda> celdas,
    String? ubicacion,
  ) async {
    llamadasUbicacion.add((
      ubicacion,
      celdas.map((c) => c.codigoInterno).toList(),
    ));
    for (var i = 0; i < celdasFalsas.length; i++) {
      if (celdas.any((c) => c.id == celdasFalsas[i].id)) {
        celdasFalsas[i] = celdasFalsas[i].copyWith(ubicacion: ubicacion);
      }
    }
    return celdas.length;
  }
}

Celda _celda(int id, String codigo, {CellState estado = CellState.received}) =>
    Celda(
      id: id,
      loteId: 1,
      codigoInterno: codigo,
      marca: 'Samsung',
      modelo: '25R',
      capacidadNominalMah: 2500,
      estado: estado,
      createdAt: DateTime(2026, 9, 20),
    );

void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  final lote = Lote(
    id: 1,
    codigo: 'L-2026-09-A',
    fechaRecepcion: DateTime(2026, 9, 2),
  );

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Future<_ControllerFalso> pump(
    WidgetTester tester, {
    required List<Celda> celdas,
  }) async {
    final c = _ControllerFalso(celdasFalsas: List.of(celdas));
    await tester.pumpWidget(
      ChangeNotifierProvider<CeldaController>.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          home: LoteCeldasScreen(lote: lote),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  group('Celdas del lote (acciones en bloque)', () {
    testWidgets('lista las celdas del lote con su etapa', (tester) async {
      phone(tester);
      await pump(tester, celdas: [
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002', estado: CellState.testing),
      ]);

      expect(find.text('C-0001'), findsOneWidget);
      expect(find.text('C-0002'), findsOneWidget);
      expect(find.text('Recepcionada'), findsOneWidget);
      expect(find.text('En test'), findsOneWidget);
      expect(find.text('2 celdas · toca para elegir'), findsOneWidget);
    });

    testWidgets('sin selección no aparece la barra de acciones',
        (tester) async {
      phone(tester);
      await pump(tester, celdas: [_celda(1, 'C-0001')]);

      expect(find.text('Etapa'), findsNothing);
      expect(find.text('Ubicación'), findsNothing);
    });

    testWidgets('al elegir una celda aparece la barra y el contador',
        (tester) async {
      phone(tester);
      await pump(tester, celdas: [
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);

      await tester.tap(find.text('C-0001'));
      await tester.pumpAndSettle();

      expect(find.text('1 elegidas'), findsOneWidget);
      expect(find.text('Etapa'), findsOneWidget);
      expect(find.text('Ubicación'), findsOneWidget);
    });

    testWidgets('"Todas" selecciona el lote entero y "Ninguna" lo limpia',
        (tester) async {
      phone(tester);
      await pump(tester, celdas: [
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
        _celda(3, 'C-0003'),
      ]);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('3 elegidas'), findsOneWidget);

      await tester.tap(find.text('Ninguna'));
      await tester.pumpAndSettle();
      expect(find.text('0 elegidas'), findsOneWidget);
    });

    testWidgets('cambiar la etapa de varias celdas de una vez', (tester) async {
      phone(tester);
      final c = await pump(tester, celdas: [
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
        _celda(3, 'C-0003'),
      ]);

      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Etapa'));
      await tester.pumpAndSettle();

      // El selector avisa de cuántas celdas se van a mover.
      expect(find.text('Mover 3 celdas a…'), findsOneWidget);

      await tester.tap(find.text('En test'));
      await tester.pumpAndSettle();

      expect(c.llamadasEtapa, hasLength(1));
      final (etapa, codigos) = c.llamadasEtapa.single;
      expect(etapa, CellState.testing);
      expect(codigos, ['C-0001', 'C-0002', 'C-0003']);
      expect(find.text('3 celdas movidas a En test'), findsOneWidget);
      // La selección se limpia tras aplicar.
      expect(find.text('0 elegidas'), findsOneWidget);
    });

    testWidgets('asignar una ubicación a las celdas elegidas', (tester) async {
      phone(tester);
      final c = await pump(tester, celdas: [
        _celda(1, 'C-0001'),
        _celda(2, 'C-0002'),
      ]);

      await tester.tap(find.text('C-0001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();

      expect(find.text('Ubicación para 1 celdas'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Estante 3');
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(c.llamadasUbicacion, hasLength(1));
      final (ubicacion, codigos) = c.llamadasUbicacion.single;
      expect(ubicacion, 'Estante 3');
      expect(codigos, ['C-0001']);
      expect(find.text('1 celdas en «Estante 3»'), findsOneWidget);
    });

    testWidgets('una ubicación vacía la quita', (tester) async {
      phone(tester);
      final c = await pump(tester, celdas: [
        Celda(
          id: 1,
          loteId: 1,
          codigoInterno: 'C-0001',
          estado: CellState.received,
          ubicacion: 'Estante 3',
          createdAt: DateTime(2026, 9, 20),
        ),
      ]);

      await tester.tap(find.text('C-0001'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ubicación'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aplicar'));
      await tester.pumpAndSettle();

      expect(c.llamadasUbicacion.single.$1, '');
      expect(find.text('Ubicación quitada a 1 celdas'), findsOneWidget);
    });

    testWidgets('un lote sin celdas lo dice en vez de quedarse vacío',
        (tester) async {
      phone(tester);
      await pump(tester, celdas: []);

      expect(find.text('Este lote no tiene celdas'), findsOneWidget);
      expect(find.text('Etapa'), findsNothing);
    });
  });
}
