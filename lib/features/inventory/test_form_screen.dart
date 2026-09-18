import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/classification.dart';
import '../../core/theme.dart';
import '../../data/models/celda.dart';
import '../../data/models/cell_test.dart';
import '../../state/celda_controller.dart';
import '../widgets/verdict_chip.dart';

/// Pantalla 4: registrar una medición. Calcula SoH y veredicto en vivo.
class TestFormScreen extends StatefulWidget {
  const TestFormScreen({super.key, required this.celda});

  final Celda celda;

  @override
  State<TestFormScreen> createState() => _TestFormScreenState();
}

class _TestFormScreenState extends State<TestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _medidaCtrl = TextEditingController();
  final _voltajeCtrl = TextEditingController();
  final _irCtrl = TextEditingController();
  final _ciclosCtrl = TextEditingController();
  final _corrienteCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _operadorCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  final DateTime _fecha = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-rellena la nominal ya medida antes, si existe.
    if (widget.celda.sohPct != null &&
        widget.celda.capacidadNominalMah != null) {
      final medida =
          widget.celda.capacidadNominalMah! * widget.celda.sohPct! / 100;
      _medidaCtrl.text = medida.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _medidaCtrl,
      _voltajeCtrl,
      _irCtrl,
      _ciclosCtrl,
      _corrienteCtrl,
      _tempCtrl,
      _operadorCtrl,
      _notasCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  ClassificationResult get _preview => classifyByCapacity(
        measuredMah: _parse(_medidaCtrl.text),
        nominalMah: widget.celda.capacidadNominalMah,
        thresholds: context.read<CeldaController>().thresholds,
      );

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    final color = AppTheme.verdictColor(preview.verdict.code);
    final nominal = widget.celda.capacidadNominalMah;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo test')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // Tarjeta de contexto de la celda.
            Card(
              child: ListTile(
                leading: VerdictChip(verdict: widget.celda.veredicto),
                title: Text(widget.celda.codigoInterno),
                subtitle: Text(
                  nominal == null
                      ? 'Sin capacidad nominal — no se podrá calcular el SoH'
                      : 'Nominal: ${nominal.toStringAsFixed(0)} mAh',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Medición', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _medidaCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Capacidad medida *',
                suffixText: 'mAh',
                prefixIcon: Icon(Icons.battery_charging_full),
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final d = _parse(v ?? '');
                if (d == null) return 'Ingresa la capacidad medida';
                if (d < 0) return 'No puede ser negativa';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _voltajeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Voltaje',
                      suffixText: 'V',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _irCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Resist. interna',
                      suffixText: 'mΩ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _corrienteCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Corriente descarga',
                      suffixText: 'A',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _tempCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Temperatura',
                      suffixText: '°C',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ciclosCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ciclos',
                      prefixIcon: Icon(Icons.repeat),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _operadorCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Operador',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notasCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notas del test',
                alignLabelWithHint: true,
              ),
            ),

            // Resultado en vivo.
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Resultado calculado',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatSoh(preview.soh),
                          style: Theme.of(context)
                              .textTheme
                              .displaySmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                      VerdictChip(verdict: preview.verdict),
                    ],
                  ),
                  if (!preview.computed && preview.reason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      preview.reason!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.check),
                label: Text(_saving ? 'Guardando…' : 'Guardar test'),
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

    final ciclos = int.tryParse(_ciclosCtrl.text.trim());
    final test = CellTest(
      celdaId: widget.celda.id ?? 0,
      fecha: _fecha,
      voltajeV: _parse(_voltajeCtrl.text),
      capacidadMedidaMah: _parse(_medidaCtrl.text),
      resistenciaInternaMohm: _parse(_irCtrl.text),
      ciclos: ciclos,
      corrienteDescargaA: _parse(_corrienteCtrl.text),
      temperaturaC: _parse(_tempCtrl.text),
      operador: _operadorCtrl.text.trim().isEmpty
          ? null
          : _operadorCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    try {
      await context.read<CeldaController>().addTest(widget.celda, test);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el test: $e')),
      );
    }
  }
}
