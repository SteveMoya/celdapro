import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:celdapro/core/agrupacion.dart';
import 'package:celdapro/core/theme.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/cell_test.dart';
import 'package:celdapro/data/repositories/celda_repository.dart';
import 'package:celdapro/data/repositories/cell_test_repository.dart';
import 'package:celdapro/features/packs/agrupacion_screen.dart';
import 'package:celdapro/state/celda_controller.dart';

/// Repositorio de celdas en memoria: la pantalla se prueba sin tocar la base.
class _CeldasFalsas extends CeldaRepository {
  _CeldasFalsas(this.lista);

  final List<Celda> lista;

  @override
  Future<List<Celda>> all({
    CeldaFilter filter = const CeldaFilter(),
    String orderBy = 'codigo_interno ASC',
  }) async =>
      lista;
}

/// Última medición de cada celda, también en memoria.
class _TestsFalsos extends CellTestRepository {
  _TestsFalsos(this.mapa);

  final Map<int, CellTest> mapa;

  @override
  Future<Map<int, CellTest>> ultimosPorCelda() async => mapa;
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  Celda celda(int id, String codigo, {Chemistry quimica = Chemistry.liIon}) =>
      Celda(
        id: id,
        codigoInterno: codigo,
        quimica: quimica,
        estado: CellState.classified,
        capacidadNominalMah: 2500,
        createdAt: DateTime(2026, 9, 20),
      );

  CellTest test(int id, double capacidad, double soh) => CellTest(
        celdaId: id,
        fecha: DateTime(2026, 9, 20),
        capacidadMedidaMah: capacidad,
        sohPct: soh,
      );

  /// Controlador con celdas y mediciones ya cargadas.
  CeldaController conDatos(List<Celda> celdas_, Map<int, CellTest> tests_) {
    final c = CeldaController(
      celdas: _CeldasFalsas(celdas_),
      tests: _TestsFalsos(tests_),
    );
    c.loading = false;
    return c;
  }

  Future<void> pump(WidgetTester tester, CeldaController c, {String? descripcion}) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          home: AgrupacionScreen(descripcion: descripcion),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Comprueba que un texto está en pantalla, bajando por la lista si hace falta.
  ///
  /// La pantalla es una lista y Flutter solo construye lo que se ve: los
  /// apartados de abajo no existen en el árbol hasta que se baja hasta ellos,
  /// así que buscarlos sin más daría un falso «no está».
  Future<void> ver(WidgetTester tester, String texto) async {
    final f = find.textContaining(texto);
    if (f.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        f,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }
    expect(f, findsOneWidget, reason: 'no apareció «$texto» en pantalla');
  }

  testWidgets('muestra los grupos armables con sus celdas y datos',
      (tester) async {
    phone(tester);
    final c = conDatos(
      [
        celda(1, 'C-0001'),
        celda(2, 'C-0002'),
        celda(3, 'C-0003'),
      ],
      {
        1: test(1, 2400, 96),
        2: test(2, 2380, 95),
        3: test(3, 2420, 96.5),
      },
    );

    await pump(tester, c);

    expect(find.textContaining('1 grupo armable'), findsOneWidget);
    expect(find.textContaining('3 celdas · Li-ion'), findsOneWidget);
    // Las celdas del grupo, por su código.
    expect(find.text('C-0001'), findsOneWidget);
    expect(find.text('C-0002'), findsOneWidget);
    expect(find.text('C-0003'), findsOneWidget);
    // Y el dato que de verdad importa al armar el pack.
    expect(find.textContaining('Capacidad aprovechable'), findsOneWidget);
  });

  testWidgets('explica por qué una celda quedó fuera', (tester) async {
    phone(tester);
    final c = conDatos(
      [celda(1, 'C-0001'), celda(2, 'C-0002'), celda(3, 'C-0003')],
      {
        1: test(1, 2400, 96),
        2: test(2, 2380, 95),
        // La tercera no tiene medición: queda fuera con su motivo.
      },
    );

    await pump(tester, c);

    await ver(tester, 'Quedaron fuera');
    await ver(tester, 'Sin medición');
    await ver(tester, 'Nunca se le hizo un test');
  });

  testWidgets('avisa cuando no hay ningún grupo armable', (tester) async {
    phone(tester);
    final c = conDatos(
      [celda(1, 'C-0001'), celda(2, 'C-0002')],
      {
        // Dos celdas muy distintas: no pueden formar pack.
        1: test(1, 2400, 96),
        2: test(2, 1500, 60),
      },
    );

    await pump(tester, c);

    await ver(tester, 'No hay ningún grupo armable');
    await ver(tester, 'Celdas sin compañía');
  });

  testWidgets('sin ninguna celda muestra un mensaje entendible', (tester) async {
    phone(tester);
    final c = conDatos(const [], const {});

    await pump(tester, c);

    expect(find.text('No hay celdas que agrupar'), findsOneWidget);
    // Y no revienta: no debe quedar ningún indicador de carga colgado.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('con celdas sin medir explica el motivo en vez de no decir nada',
      (tester) async {
    phone(tester);
    // Hay una celda, pero nunca se midió: en vez del mensaje genérico, la
    // pantalla dice por qué no se puede agrupar.
    final c = conDatos([celda(1, 'C-0001')], const {});

    await pump(tester, c);

    await ver(tester, 'Quedaron fuera');
    await ver(tester, 'Sin medición');
    expect(find.text('No hay celdas que agrupar'), findsNothing);
  });

  testWidgets('muestra el alcance cuando se agrupa un lote', (tester) async {
    phone(tester);
    final c = conDatos(
      [celda(1, 'C-0001'), celda(2, 'C-0002')],
      {1: test(1, 2400, 96), 2: test(2, 2390, 95)},
    );

    await pump(tester, c, descripcion: 'Lote L-2026-09-A');

    expect(find.text('Lote L-2026-09-A'), findsOneWidget);
  });

  testWidgets('mezclar químicas nunca da un grupo armable', (tester) async {
    phone(tester);
    final c = conDatos(
      [
        celda(1, 'C-0001', quimica: Chemistry.liIon),
        celda(2, 'C-0002', quimica: Chemistry.lfp),
      ],
      {1: test(1, 2400, 96), 2: test(2, 2400, 96)},
    );

    await pump(tester, c);

    expect(find.textContaining('No hay ningún grupo armable'), findsOneWidget);
  });

  testWidgets('las tolerancias se resumen en la cabecera', (tester) async {
    phone(tester);
    final c = conDatos(
      [celda(1, 'C-0001'), celda(2, 'C-0002')],
      {1: test(1, 2400, 96), 2: test(2, 2390, 95)},
    );
    final t = const ToleranciasAgrupacion();
    c.tolerancias = t;

    await pump(tester, c);

    expect(find.textContaining('Capacidad ±5 %'), findsOneWidget);
    expect(find.textContaining('SoH ±5 pts'), findsOneWidget);
  });
}
