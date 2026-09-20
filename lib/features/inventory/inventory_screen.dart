import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/cell_code.dart';
import '../../core/classification.dart';
import '../../data/models/celda.dart';
import '../../data/repositories/celda_repository.dart';
import '../../state/celda_controller.dart';
import '../labels/label_screen.dart';
import '../reports/report_screen.dart';
import '../widgets/metric_card.dart';
import '../widgets/state_chip.dart';
import '../widgets/verdict_chip.dart';
import 'celda_detail_screen.dart';
import 'celda_form_screen.dart';
import 'scanner_screen.dart';

/// Pantalla 2: inventario de celdas con búsqueda y filtros.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  CellState? _estado;
  Verdict? _veredicto;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    context.read<CeldaController>().setFilter(
          CeldaFilter(
            texto: _searchCtrl.text,
            estado: _estado,
            veredicto: _veredicto,
          ),
        );
  }

  bool get _hasFilter =>
      _searchCtrl.text.trim().isNotEmpty ||
      _estado != null ||
      _veredicto != null;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();

    return Scaffold(
      body: Column(
        children: [
          // Búsqueda.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar por código, marca o modelo',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _apply();
                        },
                      ),
              ),
              onChanged: (_) => _apply(),
            ),
          ),

          // Filtros.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: !_hasFilter,
                  onSelected: (_) {
                    _searchCtrl.clear();
                    setState(() {
                      _estado = null;
                      _veredicto = null;
                    });
                    _apply();
                  },
                ),
                const SizedBox(width: 8),
                for (final v in Verdict.values) ...[
                  FilterChip(
                    label: Text(v.code),
                    selected: _veredicto == v,
                    onSelected: (sel) {
                      setState(() => _veredicto = sel ? v : null);
                      _apply();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
                for (final s in [CellState.testing, CellState.rejected]) ...[
                  FilterChip(
                    label: Text(s.label),
                    selected: _estado == s,
                    onSelected: (sel) {
                      setState(() => _estado = sel ? s : null);
                      _apply();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Lista.
          Expanded(
            child: c.loading
                ? const Center(child: CircularProgressIndicator())
                : c.celdas.isEmpty
                    ? EmptyState(
                        icon: _hasFilter
                            ? Icons.search_off
                            : Icons.battery_std_outlined,
                        title: _hasFilter
                            ? 'Sin resultados'
                            : 'Inventario vacío',
                        message: _hasFilter
                            ? 'Prueba con otro código, marca o quita los filtros.'
                            : 'Registra tu primera celda y su medición.',
                      )
                    : RefreshIndicator(
                        onRefresh: c.refresh,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                          itemCount: c.celdas.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, i) =>
                              _CeldaTile(celda: c.celdas[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scan',
            tooltip: 'Escanear código',
            onPressed: () => _scan(context),
            child: const Icon(Icons.qr_code_scanner),
          ),
          if (c.celdas.isNotEmpty) ...[
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'labels',
              tooltip: 'Etiquetas del listado',
              onPressed: () => _etiquetas(context, c.celdas),
              child: const Icon(Icons.qr_code_2_outlined),
            ),
            const SizedBox(height: 10),
            FloatingActionButton.small(
              heroTag: 'report',
              tooltip: 'Informe de inventario en PDF',
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) =>
                      const ReportScreen(scope: ReportScope.inventario),
                ),
              ),
              child: const Icon(Icons.picture_as_pdf_outlined),
            ),
          ],
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'new',
            onPressed: () => _new(context),
            icon: const Icon(Icons.add),
            label: const Text('Celda'),
          ),
        ],
      ),
    );
  }

  Future<void> _etiquetas(BuildContext context, List<Celda> celdas) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LabelScreen(
          celdas: celdas,
          titulo: 'Etiquetas (${celdas.length})',
        ),
      ),
    );
  }

  Future<void> _new(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CeldaFormScreen()),
    );
    if (saved == true && context.mounted) {
      context.read<CeldaController>().refresh();
    }
  }

  /// Escanea una etiqueta: si la celda ya existe, abre su ficha; si no, abre el
  /// alta con los datos de la etiqueta ya rellenados.
  Future<void> _scan(BuildContext context) async {
    final scan = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (scan == null || !context.mounted) return;

    final payload = CellPayload.decode(scan);
    final codigo = (payload?.codigo.isNotEmpty ?? false)
        ? payload!.codigo
        : scan.trim();

    final controller = context.read<CeldaController>();
    Celda? existente;
    for (final c in controller.celdas) {
      if (c.codigoInterno.toLowerCase() == codigo.toLowerCase()) {
        existente = c;
        break;
      }
    }

    if (existente != null && existente.id != null) {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CeldaDetailScreen(celdaId: existente!.id!),
        ),
      );
      if (context.mounted) await controller.refresh();
      return;
    }

    // Etiqueta de una celda que aún no está en este dispositivo: se da de alta
    // con lo que traía la etiqueta, sin volver a escribir los datos.
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CeldaFormScreen(initialQr: codigo, initialScan: payload),
      ),
    );
    if (saved == true && context.mounted) await controller.refresh();
  }
}

class _CeldaTile extends StatelessWidget {
  const _CeldaTile({required this.celda});

  final Celda celda;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detalle = [
      if (celda.marca != null) celda.marca!,
      if (celda.modelo != null) celda.modelo!,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CeldaDetailScreen(celdaId: celda.id!),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  celda.veredicto?.code ?? '?',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      celda.codigoInterno,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (detalle.isNotEmpty)
                      Text(
                        detalle,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        StateChip(state: celda.estado),
                        if (celda.sohPct != null)
                          VerdictChip(verdict: celda.veredicto, dense: true),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (celda.sohPct != null)
                    Text(
                      formatSoh(celda.sohPct),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
