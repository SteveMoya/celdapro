import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/lote.dart';
import '../../state/celda_controller.dart';
import '../inventory/celda_form_screen.dart';

/// Alta y edición de lotes.
class LoteFormScreen extends StatefulWidget {
  const LoteFormScreen({super.key, this.lote});

  final Lote? lote;

  bool get isEdit => lote != null;

  @override
  State<LoteFormScreen> createState() => _LoteFormScreenState();
}

class _LoteFormScreenState extends State<LoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _proveedorCtrl = TextEditingController();
  final _origenCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  DateTime _fecha = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.lote;
    if (l != null) {
      _codigoCtrl.text = l.codigo;
      _proveedorCtrl.text = l.proveedor ?? '';
      _origenCtrl.text = l.origen ?? '';
      _notasCtrl.text = l.notas ?? '';
      _fecha = l.fechaRecepcion;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sugerirCodigo());
    }
  }

  Future<void> _sugerirCodigo() async {
    if (_codigoCtrl.text.isNotEmpty) return;
    final codigo = await context.read<CeldaController>().suggestLoteCodigo();
    if (mounted) setState(() => _codigoCtrl.text = codigo);
  }

  @override
  void dispose() {
    for (final c in [_codigoCtrl, _proveedorCtrl, _origenCtrl, _notasCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final celdas = widget.isEdit
        ? c.celdas.where((x) => x.loteId == widget.lote!.id).toList()
        : const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEdit ? 'Lote ${widget.lote!.codigo}' : 'Nuevo lote'),
        actions: [
          if (widget.isEdit)
            IconButton(
              tooltip: 'Eliminar lote',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(),
            ),
        ],
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
                labelText: 'Código del lote *',
                prefixIcon: Icon(Icons.qr_code_2),
              ),
              onTapOutside: (_) => _revisarCodigo(),
              onEditingComplete: _revisarCodigo,
              validator: _validarCodigo,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _proveedorCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Proveedor',
                prefixIcon: Icon(Icons.store_outlined),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _origenCtrl,
              decoration: const InputDecoration(
                labelText: 'Origen',
                hintText: 'Ej: Batería de laptop, importado…',
                prefixIcon: Icon(Icons.public),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_outlined),
                title: const Text('Fecha de recepción'),
                subtitle: Text(DateFormat('d MMM y', 'es').format(_fecha)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _pickFecha,
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

            if (widget.isEdit) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Celdas del lote (${celdas.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addCelda,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (celdas.isEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.battery_std_outlined),
                    title: const Text('Sin celdas'),
                    subtitle: Text('Añade celdas a ${widget.lote!.codigo}'),
                  ),
                )
              else
                for (final celda in celdas)
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.battery_std, size: 20),
                      title: Text(celda.codigoInterno),
                      subtitle: Text(
                        [
                          if (celda.marca != null) celda.marca!,
                          celda.estado.label,
                        ].join(' · '),
                      ),
                      trailing: celda.sohPct == null
                          ? null
                          : Text('${celda.sohPct!.toStringAsFixed(0)} %'),
                    ),
                  ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando…' : 'Guardar lote'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fecha = fecha);
  }

  Future<void> _addCelda() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CeldaFormScreen(initialLoteId: widget.lote!.id),
      ),
    );
    if (saved == true && mounted) {
      await context.read<CeldaController>().refresh();
    }
  }

  /// Comprueba el código antes de guardar.
  ///
  /// Además de exigirlo, avisa si ya existe otro lote con ese código: la base
  /// también lo impide, pero un aviso en el formulario es más útil que un
  /// error de SQLite.
  String? _validarCodigo(String? v) {
    final codigo = (v ?? '').trim();
    if (codigo.isEmpty) return 'Pon un código';
    if (_codigoDuplicado) return 'Ya existe un lote con ese código';
    return null;
  }

  /// Marca si el código escrito ya está en uso (se revisa al salir del campo).
  bool _codigoDuplicado = false;

  Future<void> _revisarCodigo() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    final existe = await context.read<CeldaController>().loteCodigoExiste(
          codigo,
          exceptId: widget.lote?.id,
        );
    if (!mounted) return;
    setState(() => _codigoDuplicado = existe);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final lote = Lote(
      id: widget.lote?.id,
      codigo: _codigoCtrl.text.trim(),
      proveedor:
          _proveedorCtrl.text.trim().isEmpty ? null : _proveedorCtrl.text.trim(),
      origen: _origenCtrl.text.trim().isEmpty ? null : _origenCtrl.text.trim(),
      fechaRecepcion: _fecha,
      notas: _notasCtrl.text.trim().isEmpty ? null : _notasCtrl.text.trim(),
    );

    final controller = context.read<CeldaController>();
    try {
      if (widget.isEdit) {
        await controller.updateLote(lote);
      } else {
        await controller.addLote(lote);
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

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar el lote?'),
        content: const Text(
          'Las celdas del lote NO se borran: se quedan sin lote asignado.',
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

    await context.read<CeldaController>().deleteLote(widget.lote!);
    if (mounted) Navigator.of(context).pop();
  }
}
