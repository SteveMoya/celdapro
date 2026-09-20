import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/cell_stats.dart';
import '../../core/classification.dart';
import '../../data/models/celda.dart';
import '../../data/models/cell_event.dart';
import '../../data/models/cell_test.dart';
import '../../data/models/lote.dart';
import '../../services/report_service.dart';
import '../../state/celda_controller.dart';

/// Qué abarca el informe.
enum ReportScope {
  inventario('Informe de inventario'),
  lote('Informe de lote'),
  celda('Ficha de celda');

  const ReportScope(this.label);
  final String label;
}

/// Vista previa, impresión y envío de un informe en PDF.
///
/// Sirve para tres cosas distintas según el alcance: el inventario completo,
/// un lote concreto o la ficha de una sola celda. El PDF se genera en el
/// teléfono, sin conexión, para poder entregárselo a un cliente.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.scope,
    this.celda,
    this.lote,
  });

  final ReportScope scope;
  final Celda? celda;
  final Lote? lote;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const _service = ReportService();

  /// Celdas que entran en el informe, según el alcance.
  List<Celda> _celdas(CeldaController c) {
    switch (widget.scope) {
      case ReportScope.celda:
        final celda = widget.celda;
        return celda == null ? const [] : [celda];
      case ReportScope.lote:
        final id = widget.lote?.id;
        if (id == null) return const [];
        return c.celdas.where((x) => x.loteId == id).toList();
      case ReportScope.inventario:
        return c.celdas;
    }
  }

  Future<Uint8List> _construir(CeldaController c) async {
    switch (widget.scope) {
      case ReportScope.celda:
        final celda = widget.celda!;
        var tests = const <CellTest>[];
        var eventos = const <CellEvent>[];
        if (celda.id != null) {
          tests = await c.testsOf(celda.id!);
          eventos = await c.eventsOf(celda.id!);
        }
        return _service.fichaCelda(
          celda: celda,
          lote: celda.loteId == null ? null : c.lotesById[celda.loteId],
          tests: tests,
          eventos: eventos,
          nombreTaller: c.nombreTaller,
          foto: await _leerFoto(celda),
        );
      case ReportScope.lote:
      case ReportScope.inventario:
        return _service.informe(
          celdas: _celdas(c),
          lotesById: c.lotesById,
          lote: widget.lote,
          thresholds: c.thresholds,
          nombreTaller: c.nombreTaller,
        );
    }
  }

  /// Lee la foto de evidencia del disco, si la hay.
  Future<Uint8List?> _leerFoto(Celda celda) async {
    final ruta = celda.fotoPath;
    if (ruta == null || ruta.isEmpty) return null;
    try {
      final f = File(ruta);
      if (!await f.exists()) return null;
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  String get _nombreArchivo {
    switch (widget.scope) {
      case ReportScope.celda:
        return 'CeldaPro-${widget.celda?.codigoInterno ?? 'celda'}.pdf';
      case ReportScope.lote:
        return 'CeldaPro-lote-${widget.lote?.codigo ?? ''}.pdf';
      case ReportScope.inventario:
        return 'CeldaPro-inventario.pdf';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CeldaController>();
    final celdas = _celdas(c);

    return Scaffold(
      appBar: AppBar(title: Text(widget.scope.label)),
      body: celdas.isEmpty && widget.scope != ReportScope.celda
          ? _vacio(context)
          : Column(
              children: [
                _resumen(context, celdas),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<Uint8List>(
                    // Se regenera al cambiar de alcance o el nombre del taller.
                    key: ValueKey('${widget.scope}-${widget.celda?.id}-'
                        '${widget.lote?.id}-${c.nombreTaller}'),
                    future: _construir(c),
                    builder: (ctx, snap) {
                      if (snap.hasError) {
                        return _error(ctx, snap.error!);
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return PdfPreview(
                        build: (_) async => snap.data!,
                        pdfFileName: _nombreArchivo,
                        initialPageFormat: PdfPageFormat.a4,
                        canChangePageFormat: false,
                        canChangeOrientation: false,
                        dynamicLayout: false,
                        allowPrinting: true,
                        allowSharing: true,
                        onError: (ctx, e) => _error(ctx, e),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _resumen(BuildContext context, List<Celda> celdas) {
    final stats = CellStats.from(celdas);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf_outlined,
              color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _descripcion(celdas.length),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (widget.scope != ReportScope.celda && celdas.isNotEmpty)
                  Text(
                    '${stats.aptas} aptas de ${stats.total}'
                    '${stats.clasificadas > 0 ? ' · SoH medio ${formatSoh(stats.avgSoh)}' : ''}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _descripcion(int n) {
    switch (widget.scope) {
      case ReportScope.celda:
        return 'Ficha completa con datos, mediciones y trazabilidad.';
      case ReportScope.lote:
        return 'Resumen y listado de las $n celdas del lote.';
      case ReportScope.inventario:
        return 'Resumen y listado de las $n celdas del inventario.';
    }
  }

  Widget _vacio(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined,
                  size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text(
                'No hay celdas que incluir en este informe.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

  Widget _error(BuildContext context, Object e) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              const Text('No se pudo generar el informe.'),
              const SizedBox(height: 8),
              Text('$e',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
}
