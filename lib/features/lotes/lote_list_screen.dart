import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../data/models/lote.dart';
import '../../state/celda_controller.dart';
import '../widgets/metric_card.dart';
import 'lote_form_screen.dart';

/// Pantalla 5: lotes con su conteo y rendimiento.
class LoteListScreen extends StatelessWidget {
  const LoteListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();

    return Scaffold(
      body: c.loading
          ? const Center(child: CircularProgressIndicator())
          : c.lotes.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'Sin lotes',
                  message: 'Agrupa las celdas por origen o compra para medir '
                      'el rendimiento de cada partida.',
                )
              : RefreshIndicator(
                  onRefresh: c.refresh,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: c.lotes.length,
                    itemBuilder: (context, i) => _LoteCard(lote: c.lotes[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _new(context),
        icon: const Icon(Icons.add),
        label: const Text('Lote'),
      ),
    );
  }

  Future<void> _new(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LoteFormScreen()),
    );
    if (saved == true && context.mounted) {
      context.read<CeldaController>().refresh();
    }
  }
}

class _LoteCard extends StatelessWidget {
  const _LoteCard({required this.lote});

  final Lote lote;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final celdas = c.celdas.where((x) => x.loteId == lote.id).toList();
    final clasificadas = celdas.where((x) => x.sohPct != null).toList();
    final rechazadas =
        clasificadas.where((x) => x.veredicto?.isRejected ?? false).length;
    final soh = clasificadas.isEmpty
        ? null
        : clasificadas.map((x) => x.sohPct!).reduce((a, b) => a + b) /
            clasificadas.length;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoteFormScreen(lote: lote),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      lote.codigo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${celdas.length} celdas',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              if (lote.proveedor != null || lote.origen != null) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if (lote.proveedor != null) lote.proveedor!,
                    if (lote.origen != null) lote.origen!,
                  ].join(' · '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Recibido: ${DateFormat('d MMM y', 'es').format(lote.fechaRecepcion)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (clasificadas.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SoH prom.: ${formatSoh(soh)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      'Rechazo: ${(rechazadas / clasificadas.length * 100).toStringAsFixed(0)} %',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: rechazadas > 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: soh == null ? 0 : (soh / 100).clamp(0, 1),
                    minHeight: 8,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
