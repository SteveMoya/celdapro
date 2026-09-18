import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/theme.dart';
import 'package:celdapro/main.dart';

void main() {
  testWidgets('la app arranca y muestra el título', (tester) async {
    await tester.pumpWidget(const CeldaProApp());
    await tester.pumpAndSettle();

    expect(find.text('CeldaPro'), findsOneWidget);
  });

  testWidgets('el tema claro y oscuro se construyen', (tester) async {
    expect(AppTheme.light().useMaterial3, isTrue);
    expect(AppTheme.dark().brightness, Brightness.dark);
  });
}
