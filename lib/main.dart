import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/home/home_shell.dart';
import 'state/celda_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Español en fechas/horas (RD).
  await initializeDateFormatting('es');
  runApp(const CeldaProApp());
}

class CeldaProApp extends StatelessWidget {
  const CeldaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CeldaController()..init(),
      child: MaterialApp(
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
        home: const HomeShell(),
      ),
    );
  }
}
