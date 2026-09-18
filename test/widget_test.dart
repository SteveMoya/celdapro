import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:celdapro/core/theme.dart';
import 'package:celdapro/features/home/home_shell.dart';
import 'package:celdapro/state/celda_controller.dart';

void main() {
  test('el tema claro y oscuro se construyen con Material 3', () {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(AppTheme.light().brightness, Brightness.light);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });

  test('los colores de veredicto están definidos', () {
    expect(AppTheme.verdictColor('A'), AppTheme.verdictA);
    expect(AppTheme.verdictColor('Rechazo'), AppTheme.verdictReject);
  });

  testWidgets('el shell arranca con las cuatro secciones', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);

    // Controlador pre-cargado: no toca la base de datos en el test.
    final c = CeldaController()..loading = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('es'),
          home: const HomeShell(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Resumen'), findsWidgets);
    expect(find.text('Inventario'), findsWidgets);
    expect(find.text('Lotes'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
  });
}
