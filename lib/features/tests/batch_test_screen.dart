import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/batch_session.dart';
import '../../core/classification.dart';
import '../../core/theme.dart';
import '../../data/models/celda.dart';
import '../../data/models/cell_test.dart';
import '../../state/celda_controller.dart';
import '../widgets/verdict_chip.dart';

/// Registro de mediciones en serie: una celda tras otra sin salir de aquí.
///
/// Es la pantalla donde se va el tiempo del taller. Está pensada para usarse
/// con una mano y el teclado numérico siempre abierto: se escribe la capacidad,
/// se ve el veredicto en vivo y se pasa a la siguiente.
class BatchTestScreen extends StatefulWidget {
  const BatchTestScreen({super.key, required this.celdas, this.titulo});

  final List<Celda> celdas;

  /// Encabezado opcional (por ejemplo el código del lote).
  final String? titulo;

  @override
  State<BatchTestScreen> createState() => _BatchTestScreenState();
}

class _BatchTestScreenState extends State<BatchTestScreen> {
  late final BatchSession _session = BatchSession(widget.celdas);
  final _focus = FocusNode();

  final _medidaCtrl = TextEditingController();
  final _voltajeCtrl = TextEditingController();
  final _irCtrl = TextEditingController();
  final _corrienteCtrl = TextEditingController();
  final _tempCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  /// El operador se mantiene entre celdas: la misma persona mide todo el lote,
  /// y volver a escribirlo veinte veces es tiempo perdido. Los datos de la
  /// medición sí se limpian, para no arrastrar la medida anterior.
  final _operadorCtrl = TextEditingController();

  bool _extras = false;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    for (final c in [
      _medidaCtrl,
      _voltajeCtrl,
      _irCtrl,
      _corrienteCtrl,
      _tempCtrl,
      _notasCtrl,
      _operadorCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _parse(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  Celda? get _celda => _session.actual;

  ClassificationResult get _preview => classifyByCapacity(
        measuredMah: _parse(_medidaCtrl.text),
        nominalMah: _celda?.capacidadNominalMah,
        thresholds: context.read<CeldaController>().thresholds,
      );

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titulo ?? 'Test masivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Anterior',
          onPressed: session.index == 0
              ? null
              : () => setState(() => session.anterior()),
        ),
        actions: [
          if (!session.vacio)
            TextButton(
              onPressed: _cerrar,
              child: const Text('Terminar'),
            ),
        ],
      ),
      body: session.vacio
          ? const _NadaPorMedir()
          : Column(
              children: [
                _Progreso(session: session),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _CeldaActual(celda: _celda!),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _medidaCtrl,
                        focusNode: _focus,
                        autofocus: true,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        // El botón "listo" del teclado guarda y pasa a la
                        // siguiente: así no hay que levantar la mano.
                        onSubmitted: (_) => _guardar(),
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Capacidad medida',
                          suffixText: 'mAh',
                          helperText: 'Escribe la medida y toca "listo" '
                              'para pasar a la siguiente',
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Resultado(preview: _preview, celda: _celda!),
                      const SizedBox(height: 8),
                      _Extras(
                        abierto: _extras,
                        onCambio: (v) => setState(() => _extras = v),
                        voltaje: _voltajeCtrl,
                        ir: _irCtrl,
                        corriente: _corrienteCtrl,
                        temperatura: _tempCtrl,
                        operador: _operadorCtrl,
                        notas: _notasCtrl,
                        irNominal: _celda?.irNominalMohm,
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLow,
                      border: Border(
                        top: BorderSide(color: scheme.outlineVariant),
                      ),
                    ),
                    child: Row(
                      children: [
                        OutlinedButton(
                          onPressed: _guardando ? null : _saltar,
                          child: const Text('Sin medir'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _guardando ? null : _guardar,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(
                              _session.restantes > 1
                                  ? 'Guardar y siguiente'
                                  : 'Guardar y terminar',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _guardar() async {
    final celda = _celda;
    if (celda == null || _guardando) return;

    final medida = _parse(_medidaCtrl.text);
    if (medida == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe la capacidad medida')),
      );
      _focus.requestFocus();
      return;
    }

    setState(() => _guardando = true);
    final controller = context.read<CeldaController>();

    final test = CellTest(
      celdaId: celda.id ?? 0,
      fecha: DateTime.now(),
      voltajeV: _parse(_voltajeCtrl.text),
      capacidadMedidaMah: medida,
      resistenciaInternaMohm: _parse(_irCtrl.text),
      ciclos: null,
      corrienteDescargaA: _parse(_corrienteCtrl.text),
      temperaturaC: _parse(_tempCtrl.text),
      operador: _operadorCtrl.text.trim().isEmpty
          ? null
          : _operadorCtrl.text.trim(),
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    try {
      await controller.addTestRapido(celda, test);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
      return;
    }

    if (!mounted) return;
    _limpiarMedicion();
    setState(() {
      _guardando = false;
      _session.siguiente();
    });
    _focus.requestFocus();

    if (_session.terminado) await _cerrar();
  }

  void _saltar() {
    _limpiarMedicion();
    setState(() => _session.saltar());
    _focus.requestFocus();
    if (_session.terminado) _cerrar();
  }

  void _limpiarMedicion() {
    _medidaCtrl.clear();
    _voltajeCtrl.clear();
    _irCtrl.clear();
    _corrienteCtrl.clear();
    _tempCtrl.clear();
    _notasCtrl.clear();
  }

  /// Cierra la sesión: recarga el inventario una sola vez y resume.
  Future<void> _cerrar() async {
    final session = _session;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = context.read<CeldaController>();

    // Durante la sesión se guardó sin recargar, así que aquí va la única
    // recarga: las listas y el dashboard quedan al día.
    await controller.refresh();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesión terminada'),
        content: Text(
          session.guardadas == 0
              ? 'No registraste ninguna medición.'
              : '${session.resumen}.\n\n'
                  'Las celdas medidas ya quedaron clasificadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Listo'),
          ),
        ],
      ),
    );

    if (session.saltadas > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${session.saltadas} celdas quedaron sin medir y siguen '
            'pendientes.',
          ),
        ),
      );
    }

    navigator.pop(true);
  }
}

/// Barra superior con el avance de la sesión.
class _Progreso extends StatelessWidget {
  const _Progreso({required this.session});

  final BatchSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        LinearProgressIndicator(
          value: session.progreso,
          minHeight: 5,
          backgroundColor: scheme.surfaceContainerHighest,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Celda ${session.index + 1} de ${session.total}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (session.guardadas > 0)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.check_circle,
                      size: 16, color: scheme.primary),
                  label: Text('${session.guardadas}'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Datos de la celda que se está midiendo.
class _CeldaActual extends StatelessWidget {
  const _CeldaActual({required this.celda});

  final Celda celda;

  @override
  Widget build(BuildContext context) {
    final nominal = celda.capacidadNominalMah;
    final modelo = [celda.marca, celda.modelo]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    celda.codigoInterno,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (modelo.isNotEmpty)
                    Text(modelo,
                        style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  nominal == null
                      ? 'Sin nominal'
                      : '${nominal.toStringAsFixed(0)} mAh',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'nominal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Veredicto y SoH calculados mientras se escribe.
class _Resultado extends StatelessWidget {
  const _Resultado({required this.preview, required this.celda});

  final ClassificationResult preview;
  final Celda celda;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.verdictColor(preview.verdict.code);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Resultado',
                    style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  formatSoh(preview.soh),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          VerdictChip(verdict: preview.verdict),
        ],
      ),
    );
  }
}

/// Datos opcionales de la medición, plegados para no estorbar.
class _Extras extends StatelessWidget {
  const _Extras({
    required this.abierto,
    required this.onCambio,
    required this.voltaje,
    required this.ir,
    required this.corriente,
    required this.temperatura,
    required this.operador,
    required this.notas,
    required this.irNominal,
  });

  final bool abierto;
  final ValueChanged<bool> onCambio;
  final TextEditingController voltaje;
  final TextEditingController ir;
  final TextEditingController corriente;
  final TextEditingController temperatura;
  final TextEditingController operador;
  final TextEditingController notas;
  final double? irNominal;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: abierto,
      onExpansionChanged: onCambio,
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('Más datos (opcional)'),
      subtitle: const Text('Voltaje, resistencia, operador…'),
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: voltaje,
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
              child: TextField(
                controller: ir,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Resist. int.',
                  suffixText: 'mΩ',
                  helperText:
                      irNominal == null ? null : 'fábrica: ${irNominal!.toInt()}',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: corriente,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Corriente',
                  suffixText: 'A',
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: temperatura,
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
        const SizedBox(height: 10),
        TextField(
          controller: operador,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Operador',
            helperText: 'Se mantiene para todas las celdas de la sesión',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: notas,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Notas de la medición',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}

/// No hay nada pendiente de medir.
class _NadaPorMedir extends StatelessWidget {
  const _NadaPorMedir();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.task_alt,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No hay celdas pendientes',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Todas las celdas de esta selección ya tienen su medición '
              'registrada.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
