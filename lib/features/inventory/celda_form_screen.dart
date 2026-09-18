import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../core/theme.dart';
import '../../data/models/celda.dart';
import '../../data/models/cell_test.dart';
import '../../data/models/lote.dart';
import '../../state/celda_controller.dart';
import '../widgets/verdict_chip.dart';

/// Alta y edición de una celda. Opcionalmente registra la primera medición
/// y muestra el veredicto calculado en vivo.
class CeldaFormScreen extends StatefulWidget {
  const CeldaFormScreen({super.key, this.celda, this.initialQr, this.initialLoteId});

  final Celda? celda;
  final String? initialQr;
  final int? initialLoteId;

  bool get isEdit => celda != null;

  @override
  State<CeldaFormScreen> createState() => _CeldaFormScreenState();
}

class _CeldaFormScreenState extends State<CeldaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _qrCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _nominalCtrl = TextEditingController();
  final _voltajeCtrl = TextEditingController();
  final _ubicacionCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();
  // Primera medición (solo al crear).
  final _medidaCtrl = TextEditingController();
  final _vMedidoCtrl = TextEditingController();
  final _irCtrl = TextEditingController();

  Chemistry _quimica = Chemistry.liIon;
  int? _loteId;
  bool _saving = false;
  bool _registrarMedicion = false;

  @override
  void initState() {
    super.initState();
    final c = widget.celda;
    if (c != null) {
      _codigoCtrl.text = c.codigoInterno;
      _qrCtrl.text = c.qr ?? '';
      _marcaCtrl.text = c.marca ?? '';
      _modeloCtrl.text = c.modelo ?? '';
      _nominalCtrl.text = c.capacidadNominalMah?.toString() ?? '';
      _voltajeCtrl.text = c.voltajeNominal?.toString() ?? '';
      _ubicacionCtrl.text = c.ubicacion ?? '';
      _notasCtrl.text = c.notas ?? '';
      _quimica = c.quimica;
      _loteId = c.loteId;
    } else {
      _qrCtrl.text = widget.initialQr ?? '';
      _loteId = widget.initialLoteId;
      WidgetsBinding.instance.addPostFrameCallback((_) => _sugerirCodigo());
    }
  }

  Future<void> _sugerirCodigo() async {
    if (_codigoCtrl.text.isNotEmpty) return;
    final codigo = await context.read<CeldaController>().suggestCodigo();
    if (mounted) setState(() => _codigoCtrl.text = codigo);
  }

  @override
  void dispose() {
    for (final c in [
      _codigoCtrl,
      _qrCtrl,
      _marcaCtrl,
      _modeloCtrl,
      _nominalCtrl,
      _voltajeCtrl,
      _ubicacionCtrl,
      _notasCtrl,
      _medidaCtrl,
      _vMedidoCtrl,
      _irCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  /// Veredicto en vivo con los datos actuales del formulario.
  ClassificationResult? get _preview {
    if (!_registrarMedicion) return null;
    return classifyByCapacity(
      measuredMah: _parse(_medidaCtrl.text),
      nominalMah: _parse(_nominalCtrl.text),
      thresholds: context.read<CeldaController>().thresholds,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final preview = _preview;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Editar celda' : 'Nueva celda'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextFormField(
              controller: _codigoCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Código interno *',
                helperText: 'Etiqueta física de la celda (único)',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Pon un código' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _qrCtrl,
              decoration: const InputDecoration(
                labelText: 'Código QR / barras',
                prefixIcon: Icon(Icons.qr_code_scanner),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int?>(
              initialValue: _loteId,
              decoration: const InputDecoration(
                labelText: 'Lote',
                prefixIcon: Icon(Icons.inventory_2_outlined),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin lote')),
                for (final Lote l in c.lotes)
                  DropdownMenuItem(value: l.id, child: Text(l.codigo)),
              ],
              onChanged: (v) => setState(() => _loteId = v),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _marcaCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Marca'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _modeloCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<Chemistry>(
              initialValue: _quimica,
              decoration: const InputDecoration(
                labelText: 'Química',
                prefixIcon: Icon(Icons.science_outlined),
              ),
              items: [
                for (final q in Chemistry.values)
                  DropdownMenuItem(value: q, child: Text(q.label)),
              ],
              onChanged: (v) => setState(() => _quimica = v ?? Chemistry.liIon),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nominalCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Capacidad nominal',
                      suffixText: 'mAh',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _voltajeCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Voltaje nominal',
                      suffixText: 'V',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _ubicacionCtrl,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                hintText: 'Ej: Estante A1',
                prefixIcon: Icon(Icons.place_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notas',
                alignLabelWithHint: true,
              ),
            ),

            // ---- Primera medición (solo al crear) ----
            if (!widget.isEdit) ...[
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _registrarMedicion,
                      onChanged: (v) =>
                          setState(() => _registrarMedicion = v),
                      title: const Text('Registrar medición ahora'),
                      subtitle: const Text(
                        'Clasifica la celda en el mismo paso',
                      ),
                      secondary: const Icon(Icons.speed),
                    ),
                    if (_registrarMedicion) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _medidaCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Capacidad medida',
                                      suffixText: 'mAh',
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: _vMedidoCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                    decoration: const InputDecoration(
                                      labelText: 'Voltaje medido',
                                      suffixText: 'V',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _irCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Resistencia interna',
                                suffixText: 'mΩ',
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (preview != null) _PreviewBox(preview: preview),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando…' : 'Guardar celda'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final controller = context.read<CeldaController>();
    final celda = Celda(
      id: widget.celda?.id,
      loteId: _loteId,
      codigoInterno: _codigoCtrl.text.trim(),
      qr: _qrCtrl.text.trim().isEmpty ? null : _qrCtrl.text.trim(),
      marca: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
      modelo: _modeloCtrl.text.trim().isEmpty ? null : _modeloCtrl.text.trim(),
      quimica: _quimica,
      capacidadNominalMah: _parse(_nominalCtrl.text),
      voltajeNominal: _parse(_voltajeCtrl.text),
      fechaFabricacion: widget.celda?.fechaFabricacion,
      estado: widget.celda?.estado ?? CellState.received,
      veredicto: widget.celda?.veredicto,
      sohPct: widget.celda?.sohPct,
      ubicacion:
          _ubicacionCtrl.text.trim().isEmpty ? null : _ubicacionCtrl.text.trim(),
      fotoPath: widget.celda?.fotoPath,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
      createdAt: widget.celda?.createdAt ?? DateTime.now(),
    );

    try {
      if (widget.isEdit) {
        await controller.updateCelda(celda);
      } else {
        CellTest? primerTest;
        if (_registrarMedicion) {
          primerTest = CellTest(
            celdaId: 0,
            fecha: DateTime.now(),
            capacidadMedidaMah: _parse(_medidaCtrl.text),
            voltajeV: _parse(_vMedidoCtrl.text),
            resistenciaInternaMohm: _parse(_irCtrl.text),
          );
        }
        await controller.addCelda(celda, firstTest: primerTest);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }
}

/// Caja con el SoH y veredicto calculados en vivo.
class _PreviewBox extends StatelessWidget {
  const _PreviewBox({required this.preview});

  final ClassificationResult preview;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = AppTheme.verdictColor(preview.verdict.code);

    if (!preview.computed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                preview.reason ?? 'Faltan datos para clasificar',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SoH calculado',
                    style: Theme.of(context).textTheme.labelMedium),
                Text(
                  formatSoh(preview.soh),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Veredicto',
                  style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 4),
              VerdictChip(verdict: preview.verdict),
            ],
          ),
        ],
      ),
    );
  }
}
