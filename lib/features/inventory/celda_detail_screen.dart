import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../core/theme.dart';
import '../../data/models/celda.dart';
import '../../data/models/cell_event.dart';
import '../../data/models/cell_test.dart';
import '../../state/celda_controller.dart';
import '../labels/label_screen.dart';
import '../reports/report_screen.dart';
import 'photo_gallery.dart';
import '../widgets/metric_card.dart';
import '../widgets/state_chip.dart';
import '../widgets/verdict_chip.dart';
import 'celda_form_screen.dart';
import 'test_form_screen.dart';

/// Pantalla 3: detalle de una celda — datos, foto, tests e historial.
class CeldaDetailScreen extends StatefulWidget {
  const CeldaDetailScreen({super.key, required this.celdaId});

  final int celdaId;

  @override
  State<CeldaDetailScreen> createState() => _CeldaDetailScreenState();
}

class _CeldaDetailScreenState extends State<CeldaDetailScreen> {
  Celda? _celda;
  List<CellTest> _tests = const [];
  List<CellEvent> _eventos = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = context.read<CeldaController>();
    if (!mounted) return;
    setState(() => _loading = true);
    final found = c.celdas.where((x) => x.id == widget.celdaId).firstOrNull;
    final tests = await c.testsOf(widget.celdaId);
    final eventos = await c.eventsOf(widget.celdaId);
    if (!mounted) return;
    setState(() {
      _celda = found;
      _tests = tests;
      _eventos = eventos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final celda = _celda;
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (celda == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'Celda no encontrada',
        ),
      );
    }

    final df = DateFormat('d MMM y, h:mm a', 'es');

    return Scaffold(
      appBar: AppBar(
        title: Text(celda.codigoInterno),
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _edit(celda),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'delete') _confirmDelete(celda);
              if (v == 'label') _etiqueta(celda);
              if (v == 'report') _informe(celda);
              if (v == 'duplicate') _duplicar(celda);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Ficha en PDF'),
                ),
              ),
              PopupMenuItem(
                value: 'duplicate',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.copy_all_outlined),
                  title: Text('Duplicar celda'),
                ),
              ),
              PopupMenuItem(
                value: 'label',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.qr_code_2_outlined),
                  title: Text('Etiqueta e imprimir'),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.delete_outline),
                  title: Text('Eliminar celda'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          // Encabezado con veredicto + SoH.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clasificación',
                            style: Theme.of(context).textTheme.labelMedium),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            VerdictChip(verdict: celda.veredicto),
                            const SizedBox(width: 10),
                            Text(
                              formatSoh(celda.sohPct),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  StateChip(state: celda.estado),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Fotos de evidencia (galería con etiquetas).
          PhotoGallery(celda: celda),
          const SizedBox(height: 14),

          // Datos.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  _row(context, 'Modelo de referencia', celda.catalogRef),
                  _row(context, 'Lote', _loteName(celda)),
                  _row(context, 'Marca', celda.marca),
                  _row(context, 'Modelo', celda.modelo),
                  _row(context, 'Química', celda.quimica.label),
                  _row(
                    context,
                    'Capacidad nominal',
                    celda.capacidadNominalMah == null
                        ? null
                        : '${celda.capacidadNominalMah!.toStringAsFixed(0)} mAh',
                  ),
                  _row(
                    context,
                    'Voltaje nominal',
                    celda.voltajeNominal == null
                        ? null
                        : '${celda.voltajeNominal} V',
                  ),
                  _row(
                    context,
                    'Resistencia de fábrica',
                    celda.irNominalMohm == null
                        ? null
                        : '${celda.irNominalMohm} mΩ',
                  ),
                  _row(context, 'QR', celda.qr),
                  _row(context, 'Ubicación', celda.ubicacion),
                  _row(
                    context,
                    'Registrada',
                    DateFormat('d MMM y', 'es').format(celda.createdAt),
                  ),
                  _row(context, 'Notas', celda.notas),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Etapa del proceso.
          Text('Etapa del proceso',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in CellState.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: celda.estado == s,
                      onSelected: (_) => _changeState(celda, s),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Tests.
          Row(
            children: [
              Expanded(
                child: Text('Tests (${_tests.length})',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (_tests.length > 1)
                TextButton(
                  onPressed: () => _showChart(celda),
                  child: const Text('Ver evolución'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (_tests.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.speed),
                title: const Text('Sin mediciones'),
                subtitle: const Text('Registra la primera para clasificar'),
              ),
            )
          else
            for (final t in _tests)
              Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  leading: VerdictChip(verdict: t.veredicto, dense: true),
                  title: Text(formatSoh(t.sohPct)),
                  subtitle: Text(
                    [
                      if (t.capacidadMedidaMah != null)
                        '${t.capacidadMedidaMah!.toStringAsFixed(0)} mAh',
                      if (t.voltajeV != null) '${t.voltajeV} V',
                      if (t.resistenciaInternaMohm != null)
                        '${t.resistenciaInternaMohm} mΩ',
                      if (t.ciclos != null) '${t.ciclos} ciclos',
                    ].join(' · '),
                  ),
                  trailing: Text(
                    df.format(t.fecha),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
          const SizedBox(height: 20),

          // Historial / trazabilidad.
          Text('Historial', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  if (_eventos.isEmpty)
                    const Text('Sin eventos registrados')
                  else
                    for (var i = 0; i < _eventos.length; i++)
                      _eventRow(context, _eventos[i], isLast: i == _eventos.length - 1),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newTest(celda),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo test'),
      ),
    );
  }

  String? _loteName(Celda celda) {
    if (celda.loteId == null) return null;
    final lote = context.read<CeldaController>().lotesById[celda.loteId];
    return lote?.codigo;
  }

  Widget _row(BuildContext context, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: Text(value),
    );
  }

  Widget _eventRow(BuildContext context, CellEvent e, {required bool isLast}) {
    final scheme = Theme.of(context).colorScheme;
    final df = DateFormat('d MMM y, h:mm a', 'es');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(_eventIcon(e), size: 18, color: scheme.primary),
            if (!isLast)
              Container(width: 2, height: 34, color: scheme.outlineVariant),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.tipo.label,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (e.nota != null) Text(e.nota!),
                Text(
                  df.format(e.fecha),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _eventIcon(CellEvent e) => switch (e.tipo) {
        EventType.created => Icons.add_circle_outline,
        EventType.stateChanged => Icons.sync_alt,
        EventType.tested => Icons.speed,
        EventType.edited => Icons.edit_outlined,
        EventType.photo => Icons.photo_camera_outlined,
        EventType.note => Icons.sticky_note_2_outlined,
      };

  // ---------- Acciones ----------

  Future<void> _etiqueta(Celda celda) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LabelScreen(
          celdas: [celda],
          titulo: 'Etiqueta ${celda.codigoInterno}',
        ),
      ),
    );
  }

  /// Ficha de la celda en PDF (para entregar al cliente).
  Future<void> _informe(Celda celda) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ReportScreen(
          scope: ReportScope.celda,
          celda: celda,
        ),
      ),
    );
  }

  /// Copia la celda con un código nuevo, para casos repetidos.
  ///
  /// La copia nace recepcionada y sin historial: los datos técnicos se copian,
  /// las mediciones y las fotos no (serían de la celda original).
  Future<void> _duplicar(Celda celda) async {
    final controller = context.read<CeldaController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final int nuevoId;
    try {
      nuevoId = await controller.duplicarCelda(celda);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo duplicar: $e')),
      );
      return;
    }
    if (!mounted) return;

    messenger.showSnackBar(
      const SnackBar(content: Text('Celda duplicada con un código nuevo')),
    );
    await navigator.push<void>(
      MaterialPageRoute(builder: (_) => CeldaDetailScreen(celdaId: nuevoId)),
    );
  }

  Future<void> _newTest(Celda celda) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TestFormScreen(celda: celda)),
    );
    if (saved == true) await _load();
  }

  Future<void> _edit(Celda celda) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CeldaFormScreen(celda: celda)),
    );
    if (saved == true) await _load();
  }

  Future<void> _changeState(Celda celda, CellState nuevo) async {
    if (celda.estado == nuevo) return;

    String? nota;
    if (nuevo == CellState.rejected) {
      final razones = context.read<CeldaController>().rejectReasons;
      if (mounted) {
        nota = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Motivo del rechazo'),
            children: [
              for (final r in razones)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(ctx).pop(r),
                  child: Text(r),
                ),
            ],
          ),
        );
      }
      if (nota == null) return; // cancelado
    }

    if (!mounted) return;
    await context.read<CeldaController>().changeState(celda, nuevo, nota: nota);
    await _load();
  }

  Future<void> _confirmDelete(Celda celda) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar la celda?'),
        content: Text(
          'Se borrarán ${celda.codigoInterno} y sus tests e historial. '
          'No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    await context.read<CeldaController>().deleteCelda(celda);
    if (mounted) Navigator.of(context).pop();
  }

  /// Evolución simple del SoH a lo largo de los tests.
  void _showChart(Celda celda) {
    final conSoh = _tests.where((t) => t.sohPct != null).toList().reversed.toList();
    if (conSoh.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Evolución del SoH',
                style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Cada celda puede medirse varias veces; aquí ves la tendencia.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            for (final t in conSoh)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: Text(
                        DateFormat('d MMM y', 'es').format(t.fecha),
                        style: Theme.of(ctx).textTheme.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: (t.sohPct! / 100).clamp(0, 1),
                          minHeight: 14,
                          color: AppTheme.verdictColor(t.veredicto?.code ?? ''),
                          backgroundColor:
                              Theme.of(ctx).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 64,
                      child: Text(
                        formatSoh(t.sohPct),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
