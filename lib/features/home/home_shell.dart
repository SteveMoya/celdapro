import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/celda_controller.dart';
import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../lotes/lote_list_screen.dart';
import '../packs/agrupacion_screen.dart';
import '../settings/settings_screen.dart';

/// Contenedor principal con navegación inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Índice de la pestaña de Ajustes.
  static const ajustesTab = 3;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  /// Permite que una pantalla (p. ej. el aviso de respaldo del resumen) lleve
  /// al usuario a otra pestaña.
  final _tab = ValueNotifier<int>(0);

  static const _titles = ['Resumen', 'Inventario', 'Lotes', 'Ajustes'];

  @override
  void initState() {
    super.initState();
    _tab.addListener(_onTab);
  }

  void _onTab() {
    if (_tab.value != _index) setState(() => _index = _tab.value);
  }

  @override
  void dispose() {
    _tab.removeListener(_onTab);
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          // Agrupar para packs tiene sentido sobre el inventario: se agrupa lo
          // que cumpla el filtro que el usuario tenga puesto en ese momento.
          if (_index == 1)
            IconButton(
              tooltip: 'Agrupar para packs',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () {
                final filtro = context.read<CeldaController>().filter;
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => AgrupacionScreen(filtro: filtro),
                  ),
                );
              },
            ),
        ],
      ),
      body: ChangeNotifierProvider<ValueNotifier<int>>.value(
        value: _tab,
        child: IndexedStack(
          index: _index,
          children: const [
            DashboardScreen(),
            InventoryScreen(),
            LoteListScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.battery_std_outlined),
            selectedIcon: Icon(Icons.battery_std),
            label: 'Inventario',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Lotes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
