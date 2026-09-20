import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../dashboard/dashboard_screen.dart';
import '../inventory/inventory_screen.dart';
import '../lotes/lote_list_screen.dart';
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
      appBar: AppBar(title: Text(_titles[_index])),
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
