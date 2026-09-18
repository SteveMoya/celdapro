import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../services/csv_service.dart';
import '../../state/celda_controller.dart';
import '../widgets/verdict_chip.dart';

/// Pantalla 6: umbrales de clasificación, motivos de rechazo y datos (CSV).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Clasificación', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Define a partir de qué SoH (capacidad medida ÷ nominal) una celda '
          'es A, B o C. Por debajo del mínimo de C se rechaza.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        _ThresholdCard(controller: c),
        const SizedBox(height: 22),

        Text('Motivos de rechazo',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              for (final r in c.rejectReasons)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.block, size: 20),
                  title: Text(r),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Quitar',
                    onPressed: () => c.saveRejectReasons(
                      [...c.rejectReasons]..remove(r),
                    ),
                  ),
                ),
              ListTile(
                dense: true,
                leading: const Icon(Icons.add),
                title: const Text('Añadir motivo'),
                onTap: () => _addReason(context, c),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text('Datos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file),
                title: const Text('Exportar inventario (CSV)'),
                subtitle: Text('${c.total} celda(s)'),
                onTap: c.total == 0 ? null : () => _export(context, c),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Importar inventario (CSV)'),
                subtitle: const Text('Carga celdas desde un archivo'),
                onTap: () => _import(context, c),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Text('Privacidad y seguridad',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Importante',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Todos los datos se guardan SOLO en este teléfono. La app no '
                  'envía nada a ningún servidor y no necesita cuenta.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Esta app organiza el proceso, no sustituye las normas de '
                  'seguridad del taller: las celdas hinchadas, dañadas o sin '
                  'tensión deben ir a rechazo/aislamiento, nunca a reempaque.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            'CeldaPro 0.1.0 — 100 % local',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Future<void> _addReason(BuildContext context, CeldaController c) async {
    final ctrl = TextEditingController();
    final texto = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo motivo de rechazo'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ej: Fuga de electrolito'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
    if (texto != null && texto.isNotEmpty) {
      await c.saveRejectReasons([...c.rejectReasons, texto]);
    }
  }

  Future<void> _export(BuildContext context, CeldaController c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final csv = const CsvService().buildCsv(
        celdas: c.celdas,
        lotesById: c.lotesById,
      );
      await const CsvService().shareCsv(csv);
      messenger.showSnackBar(
        const SnackBar(content: Text('Inventario exportado')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo exportar: $e')),
      );
    }
  }

  Future<void> _import(BuildContext context, CeldaController c) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
      );
      final path = files.isEmpty ? null : files.first.path;
      if (path == null) return;

      final content = await File(path).readAsString();
      final parsed = const CsvService().parseCsv(content);

      if (parsed.celdas.isEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              parsed.errors.isEmpty
                  ? 'El archivo no tiene celdas'
                  : 'No se importó nada: ${parsed.errors.first}',
            ),
          ),
        );
        return;
      }

      final summary = await c.importCeldas(parsed.celdas);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Importadas ${summary.imported} celda(s).'
            '${summary.skipped.isEmpty ? '' : ' Omitidas ${summary.skipped.length} por código repetido.'}',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo importar: $e')),
      );
    }
  }
}

/// Editor de umbrales con vista previa del veredicto.
class _ThresholdCard extends StatefulWidget {
  const _ThresholdCard({required this.controller});

  final CeldaController controller;

  @override
  State<_ThresholdCard> createState() => _ThresholdCardState();
}

class _ThresholdCardState extends State<_ThresholdCard> {
  late double _a;
  late double _b;
  late double _c;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final t = widget.controller.thresholds;
    _a = t.aMin;
    _b = t.bMin;
    _c = t.cMin;
  }

  @override
  Widget build(BuildContext context) {
    final t = Thresholds(aMin: _a, bMin: _b, cMin: _c).sanitized();
    final preview = [95.0, 80.0, 65.0, 50.0];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _slider('A desde', _a, (v) => setState(() {
                  _a = v;
                  _dirty = true;
                })),
            _slider('B desde', _b, (v) => setState(() {
                  _b = v;
                  _dirty = true;
                })),
            _slider('C desde', _c, (v) => setState(() {
                  _c = v;
                  _dirty = true;
                })),
            const Divider(height: 24),
            Text('Vista previa', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 6,
              children: [
                for (final soh in preview)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${soh.toStringAsFixed(0)} % → ',
                          style: Theme.of(context).textTheme.bodySmall),
                      VerdictChip(verdict: classifySoh(soh, t), dense: true),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _dirty
                    ? () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await widget.controller.saveThresholds(t);
                        if (!mounted) return;
                        setState(() => _dirty = false);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Umbrales guardados')),
                        );
                      }
                    : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar umbrales'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${value.toStringAsFixed(0)} %',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, 100),
          max: 100,
          divisions: 100,
          label: '${value.toStringAsFixed(0)} %',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
