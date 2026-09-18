import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme.dart';

void main() {
  runApp(const CeldaProApp());
}

class CeldaProApp extends StatelessWidget {
  const CeldaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CeldaPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Placeholder(),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('CeldaPro')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.battery_charging_full, size: 72, color: scheme.primary),
            const SizedBox(height: 12),
            const Text('Gestión de restauración de celdas de litio'),
          ],
        ),
      ),
    );
  }
}
