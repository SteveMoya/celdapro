import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../data/models/celda.dart';
import '../../state/celda_controller.dart';
import '../home/home_shell.dart';
import '../widgets/metric_card.dart';
import '../widgets/state_chip.dart';
import '../widgets/verdict_chip.dart';

/// Pantalla 1: resumen del proceso (métricas reales del taller).
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final scheme = Theme.of(context).colorScheme;

    if (c.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (c.total == 0) {
      return const EmptyState(
        icon: Icons.battery_charging_full,
        title: 'Aún no hay celdas registradas',
        message: 'Empieza en la pestaña Inventario: pulsa + para dar de alta '
            'tu primera celda y registrar su medición.',
      );
    }

    final recientes = c.celdas.take(5).toList();

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // Aviso de respaldo: los datos solo viven en este teléfono.
          if (c.tocaRespaldar) ...[
            _AvisoRespaldo(dias: c.diasSinRespaldo),
            const SizedBox(height: 14),
          ],
          // Métricas principales.
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: [
              MetricCard(
                label: 'Celdas totales',
                value: '${c.total}',
                icon: Icons.battery_std,
              ),
              MetricCard(
                label: 'Clasificadas',
                value: '${c.classifiedCount}',
                icon: Icons.verified_outlined,
              ),
              MetricCard(
                label: 'SoH promedio',
                value: formatSoh(c.avgSoh),
                icon: Icons.trending_up,
                hint: 'capacidad medida / nominal',
              ),
              MetricCard(
                label: '% Rechazo',
                value: '${c.rejectionRate.toStringAsFixed(1)} %',
                icon: Icons.report_gmailerrorred_outlined,
                color: c.rejectionRate > 30 ? scheme.error : null,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Distribución por veredicto.
          Text('Por veredicto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final v in Verdict.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          VerdictChip(verdict: v, dense: true),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              v.label,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${c.countsByVeredicto[v] ?? 0}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Estado del proceso.
          Text('Etapa del proceso',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  for (final s in CellState.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          Expanded(child: StateChip(state: s)),
                          Text(
                            '${c.countsByEstado[s] ?? 0}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actividad reciente.
          if (recientes.isNotEmpty) ...[
            Text('Celdas recientes',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final celda in recientes)
                    ListTile(
                      dense: true,
                      leading: VerdictChip(verdict: celda.veredicto, dense: true),
                      title: Text(celda.codigoInterno),
                      subtitle: Text(
                        DateFormat('d MMM y', 'es').format(celda.createdAt),
                      ),
                      trailing: celda.sohPct == null
                          ? null
                          : Text(formatSoh(celda.sohPct)),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Recordatorio de respaldo cuando el último es viejo (o no existe).
class _AvisoRespaldo extends StatelessWidget {
  const _AvisoRespaldo({required this.dias});

  final int? dias;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final texto = dias == null
        ? 'Todavía no has hecho ningún respaldo'
        : 'Último respaldo: hace $dias ${dias == 1 ? "día" : "días"}';

    return Card(
      color: scheme.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: scheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    texto,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Todo el historial del taller vive en este teléfono. '
                    'Guarda una copia fuera por si se pierde o se estropea.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                // Lleva a la pestaña de Ajustes, donde está el respaldo.
                context.read<ValueNotifier<int>>().value =
                    HomeShell.ajustesTab;
              },
              child: const Text('Respaldar'),
            ),
          ],
        ),
      ),
    );
  }
}
