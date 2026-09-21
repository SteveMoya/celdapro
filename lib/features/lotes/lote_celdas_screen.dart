import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/celda.dart';
import '../../data/models/lote.dart';
import '../../data/repositories/celda_repository.dart';
import '../../state/celda_controller.dart';
import '../packs/agrupacion_screen.dart';
import '../widgets/state_chip.dart';
import '../widgets/verdict_chip.dart';

/// Pantalla de trabajo sobre un lote: elegir varias celdas y aplicarles el
/// mismo cambio de una sola vez (etapa u ubicación).
///
/// Existe porque mover 80 celdas de "Recepcionada" a "En test" de una en una
/// es donde se pierde la tarde. El cambio en masa **no pierde trazabilidad**:
/// cada celda queda con su propio evento en el historial.
class LoteCeldasScreen extends StatefulWidget {
  const LoteCeldasScreen({super.key, required this.lote});

  final Lote lote;

  @override
  State<LoteCeldasScreen> createState() => _LoteCeldasScreenState();
}

class _LoteCeldasScreenState extends State<LoteCeldasScreen> {
  final Set<int> _seleccion = {};
  bool _ocupado = false;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final celdas = c.celdas.where((x) => x.loteId == widget.lote.id).toList()
      ..sort((a, b) => a.codigoInterno.compareTo(b.codigoInterno));

    // Una celda borrada o cambiada de lote no puede seguir seleccionada.
    _seleccion.removeWhere((id) => !celdas.any((x) => x.id == id));

    final seleccionadas =
        celdas.where((x) => x.id != null && _seleccion.contains(x.id)).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.lote.codigo),
        actions: [
          IconButton(
            tooltip: 'Agrupar las celdas del lote para packs',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () => Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => AgrupacionScreen(
                  filtro: CeldaFilter(loteId: widget.lote.id),
                  titulo: 'Agrupar el lote',
                  descripcion: 'Lote ${widget.lote.codigo}',
                ),
              ),
            ),
          ),
          if (celdas.isNotEmpty)
            TextButton(
              onPressed: _ocupado
                  ? null
                  : () => setState(() {
                        if (_seleccion.length == celdas.length) {
                          _seleccion.clear();
                        } else {
                          _seleccion
                            ..clear()
                            ..addAll(celdas
                                .map((x) => x.id)
                                .whereType<int>());
                        }
                      }),
              child: Text(
                _seleccion.length == celdas.length ? 'Ninguna' : 'Todas',
              ),
            ),
        ],
      ),
      body: celdas.isEmpty
          ? const _LoteVacio()
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${celdas.length} celdas · toca para elegir',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Text(
                        '${_seleccion.length} elegidas',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 96),
                    itemCount: celdas.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) => _FilaCelda(
                      celda: celdas[i],
                      seleccionada: celdas[i].id != null &&
                          _seleccion.contains(celdas[i].id),
                      onCambio: celdas[i].id == null
                          ? null
                          : (v) => setState(() {
                                if (v == true) {
                                  _seleccion.add(celdas[i].id!);
                                } else {
                                  _seleccion.remove(celdas[i].id!);
                                }
                              }),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: seleccionadas.isEmpty
          ? null
          : _BarraAcciones(
              cantidad: seleccionadas.length,
              ocupado: _ocupado,
              onEtapa: () => _cambiarEtapa(seleccionadas),
              onUbicacion: () => _asignarUbicacion(seleccionadas),
            ),
    );
  }

  // ---------- Acciones ----------

  Future<void> _cambiarEtapa(List<Celda> celdas) async {
    final elegida = await showModalBottomSheet<CellState>(
      context: context,
      showDragHandle: true,
      // Las 7 etapas no caben en pantallas pequeñas: la hoja se desplaza
      // en vez de desbordarse.
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Mover ${celdas.length} celdas a…',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final estado in CellState.values)
                ListTile(
                  leading: Icon(_iconoEtapa(estado)),
                  title: Text(estado.label),
                  subtitle: Text(estado.description),
                  onTap: () => Navigator.of(ctx).pop(estado),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (elegida == null || !mounted) return;

    await _ejecutar(
      () => context.read<CeldaController>().cambiarEstadoEnBloque(
            celdas,
            elegida,
            nota: 'Cambio en bloque a ${elegida.label}',
          ),
      (n) => n == 0
          ? 'Esas celdas ya estaban en ${elegida.label}'
          : '$n celdas movidas a ${elegida.label}',
    );
  }

  Future<void> _asignarUbicacion(List<Celda> celdas) async {
    final ctrl = TextEditingController();
    final ubicacion = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ubicación para ${celdas.length} celdas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Déjalo vacío para quitar la ubicación.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ubicación',
                hintText: 'Estante 3, caja B',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (ubicacion == null || !mounted) return;

    final limpia = ubicacion.trim();
    await _ejecutar(
      () => context.read<CeldaController>()
          .asignarUbicacionEnBloque(celdas, limpia),
      (n) => n == 0
          ? 'Sin cambios'
          : limpia.isEmpty
              ? 'Ubicación quitada a $n celdas'
              : '$n celdas en «$limpia»',
    );
  }

  /// Ejecuta una acción en bloque, avisa del resultado y limpia la selección.
  Future<void> _ejecutar(
    Future<int> Function() accion,
    String Function(int cambiadas) mensaje,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _ocupado = true);
    try {
      final cambiadas = await accion();
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _seleccion.clear();
      });
      messenger.showSnackBar(SnackBar(content: Text(mensaje(cambiadas))));
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo aplicar el cambio: $e')),
      );
    }
  }

  static IconData _iconoEtapa(CellState e) => switch (e) {
        CellState.received => Icons.inbox_outlined,
        CellState.testing => Icons.science_outlined,
        CellState.classified => Icons.verified_outlined,
        CellState.balanced => Icons.balance,
        CellState.repacked => Icons.view_module_outlined,
        CellState.qaPassed => Icons.verified,
        CellState.rejected => Icons.block_outlined,
      };
}

/// Una celda de la lista, con su casilla.
class _FilaCelda extends StatelessWidget {
  const _FilaCelda({
    required this.celda,
    required this.seleccionada,
    required this.onCambio,
  });

  final Celda celda;
  final bool seleccionada;
  final ValueChanged<bool?>? onCambio;

  @override
  Widget build(BuildContext context) {
    final modelo = [celda.marca, celda.modelo]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return CheckboxListTile(
      value: seleccionada,
      onChanged: onCambio,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Expanded(
            child: Text(
              celda.codigoInterno,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          if (celda.veredicto != null) VerdictChip(verdict: celda.veredicto),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (modelo.isNotEmpty) Text(modelo),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              StateChip(state: celda.estado),
              if (celda.ubicacion != null && celda.ubicacion!.isNotEmpty)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.place_outlined, size: 14),
                  label: Text(celda.ubicacion!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Barra inferior con las acciones sobre la selección.
class _BarraAcciones extends StatelessWidget {
  const _BarraAcciones({
    required this.cantidad,
    required this.ocupado,
    required this.onEtapa,
    required this.onUbicacion,
  });

  final int cantidad;
  final bool ocupado;
  final VoidCallback onEtapa;
  final VoidCallback onUbicacion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: ocupado ? null : onEtapa,
                icon: const Icon(Icons.swap_horiz, size: 20),
                label: const Text('Etapa', overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: ocupado ? null : onUbicacion,
                icon: const Icon(Icons.place_outlined, size: 20),
                label: const Text('Ubicación', overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El lote todavía no tiene celdas.
class _LoteVacio extends StatelessWidget {
  const _LoteVacio();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Este lote no tiene celdas',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Da de alta celdas eligiendo este lote para poder trabajar '
              'con ellas aquí.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
