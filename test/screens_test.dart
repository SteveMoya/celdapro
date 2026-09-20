import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'package:celdapro/core/classification.dart';
import 'package:celdapro/core/theme.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/features/dashboard/dashboard_screen.dart';
import 'package:celdapro/features/inventory/inventory_screen.dart';
import 'package:celdapro/features/reports/report_screen.dart';
import 'package:celdapro/features/settings/settings_screen.dart';
import 'package:celdapro/state/celda_controller.dart';

/// Pantallas con un controlador pre-cargado (sin tocar la base de datos).
void main() {
  setUpAll(() async => initializeDateFormatting('es'));

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
  }

  CeldaController fake({
    List<Celda> celdas = const [],
    int total = 0,
    Map<Verdict, int> porVeredicto = const {},
    Map<CellState, int> porEstado = const {},
    double? avgSoh,
  }) {
    final c = CeldaController();
    c.loading = false;
    c.celdas = celdas;
    c.total = total;
    c.countsByVeredicto = porVeredicto;
    c.countsByEstado = porEstado;
    c.avgSoh = avgSoh;
    return c;
  }

  Future<void> pump(WidgetTester tester, Widget child, CeldaController c) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard vacío muestra el estado inicial', (tester) async {
    phone(tester);
    await pump(tester, const DashboardScreen(), fake());
    expect(find.text('Aún no hay celdas registradas'), findsOneWidget);
  });

  testWidgets('dashboard muestra las métricas reales', (tester) async {
    phone(tester);
    final c = fake(
      total: 10,
      porVeredicto: {Verdict.a: 6, Verdict.b: 2, Verdict.reject: 2},
      porEstado: {CellState.classified: 8, CellState.rejected: 2},
      avgSoh: 88.5,
    );
    await pump(tester, const DashboardScreen(), c);

    expect(find.text('Celdas totales'), findsOneWidget);
    expect(find.text('SoH promedio'), findsOneWidget);
    // "10" aparece dos veces: celdas totales (10) y clasificadas (6+2+2).
    expect(find.text('10'), findsNWidgets(2));
    expect(find.text('88.5 %'), findsOneWidget); // SoH promedio
    expect(find.text('20.0 %'), findsOneWidget); // % rechazo (2 de 10)
  });

  testWidgets('inventario vacío muestra su estado y no colapsa el texto',
      (tester) async {
    phone(tester);
    await pump(tester, const InventoryScreen(), fake());

    expect(find.text('Inventario vacío'), findsOneWidget);
    final w = tester.getSize(find.text('Inventario vacío')).width;
    expect(w, greaterThan(80));
  });

  testWidgets('inventario lista las celdas con su veredicto', (tester) async {
    phone(tester);
    final c = fake(
      total: 2,
      celdas: [
        Celda(
          id: 1,
          codigoInterno: 'C-0001',
          marca: 'Samsung',
          capacidadNominalMah: 2500,
          estado: CellState.classified,
          veredicto: Verdict.a,
          sohPct: 94.0,
          createdAt: DateTime(2026, 9, 17),
        ),
        Celda(
          id: 2,
          codigoInterno: 'C-0002',
          marca: 'LG',
          estado: CellState.received,
          createdAt: DateTime(2026, 9, 17),
        ),
      ],
    );
    await pump(tester, const InventoryScreen(), c);

    expect(find.text('C-0001'), findsOneWidget);
    expect(find.text('C-0002'), findsOneWidget);
    expect(find.text('94.0 %'), findsOneWidget);
  });

  testWidgets('ajustes muestra los umbrales y la vista previa',
      (tester) async {
    phone(tester);
    await pump(tester, const SettingsScreen(), fake());
    await tester.pumpAndSettle();

    expect(find.text('Clasificación'), findsOneWidget);
    expect(find.text('Vista previa'), findsOneWidget);
    expect(find.text('A desde'), findsOneWidget);
    expect(find.text('95 % → '), findsOneWidget);
  });

  testWidgets('la lista de inventario no colapsa textos junto a botones',
      (tester) async {
    phone(tester);
    final c = fake(
      total: 1,
      celdas: [
        Celda(
          id: 1,
          codigoInterno: 'C-0007',
          marca: 'Molicel',
          capacidadNominalMah: 3000,
          estado: CellState.testing,
          veredicto: Verdict.b,
          sohPct: 78.0,
          createdAt: DateTime(2026, 9, 17),
        ),
      ],
    );
    await pump(tester, const InventoryScreen(), c);

    expect(tester.getSize(find.text('C-0007')).width, greaterThan(60));
  });

  testWidgets('el informe de inventario sin celdas avisa en vez de fallar',
      (tester) async {
    phone(tester);
    await pump(
      tester,
      const ReportScreen(scope: ReportScope.inventario),
      fake(),
    );

    expect(find.textContaining('No hay celdas'), findsOneWidget);
  });

  testWidgets('el informe de un lote sin celdas avisa', (tester) async {
    phone(tester);
    await pump(
      tester,
      ReportScreen(
        scope: ReportScope.lote,
        lote: Lote(
          id: 1,
          codigo: 'L-2026-09-A',
          fechaRecepcion: DateTime(2026, 9, 2),
        ),
      ),
      fake(),
    );

    expect(find.textContaining('No hay celdas'), findsOneWidget);
  });

  testWidgets('la ficha sin celda muestra un error entendible',
      (tester) async {
    phone(tester);
    await pump(
      tester,
      const ReportScreen(scope: ReportScope.celda),
      fake(),
    );
    await tester.pumpAndSettle();

    expect(find.text('No se pudo generar el informe.'), findsOneWidget);
  });
}
