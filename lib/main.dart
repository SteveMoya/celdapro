import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme.dart';
import 'features/home/home_shell.dart';
import 'features/updates/update_controller.dart';
import 'state/celda_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Español en fechas/horas (RD).
  await initializeDateFormatting('es');
  runApp(const CeldaProApp());
}

class CeldaProApp extends StatefulWidget {
  const CeldaProApp({super.key});

  @override
  State<CeldaProApp> createState() => _CeldaProAppState();
}

class _CeldaProAppState extends State<CeldaProApp>
    with WidgetsBindingObserver {
  late final CeldaController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = CeldaController();
    _arrancar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Carga los datos y, cuando la UI ya está montada, revisa si hay versión
  /// nueva. La revisión va al final y nunca bloquea ni rompe el arranque.
  Future<void> _arrancar() async {
    try {
      await _controller.init();
    } catch (e) {
      debugPrint('No se pudo cargar el inventario: $e');
    }
    if (!mounted) return;
    if (!_controller.updateAutomatico) return;
    try {
      await UpdateController.instance.verificar();
    } catch (e) {
      debugPrint('Revisión de actualizaciones falló: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    // Al volver a primer plano se re-revisa si hay versión nueva (con un
    // mínimo de 3 minutos entre revisiones, para no golpear la red).
    if (estado == AppLifecycleState.resumed && _controller.updateAutomatico) {
      unawaited(UpdateController.instance.verificar());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CeldaController>.value(
      value: _controller,
      child: MaterialApp(
        title: 'CeldaPro',
        debugShowCheckedModeBanner: false,
        navigatorKey: UpdateController.instance.navigatorKey,
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
