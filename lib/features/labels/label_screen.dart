import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../core/cell_code.dart';
import '../../data/models/celda.dart';
import '../../data/models/lote.dart';
import '../../services/code_service.dart';
import '../../services/label_service.dart';
import '../../state/celda_controller.dart';

/// Vista previa e impresión de etiquetas de celda.
///
/// Cada etiqueta lleva tres cosas: el **código de barras** con el identificador
/// (para escanear rápido), el **QR** con la ficha completa de la celda y los
/// datos **en texto legible** (para cuando la etiqueta se estropea).
class LabelScreen extends StatefulWidget {
  const LabelScreen({
    super.key,
    required this.celdas,
    this.titulo = 'Etiquetas',
  });

  final List<Celda> celdas;
  final String titulo;

  @override
  State<LabelScreen> createState() => _LabelScreenState();
}

class _LabelScreenState extends State<LabelScreen> {
  static const _service = LabelService();

  LabelFormat _formato = LabelFormat.celda;
  bool _generando = false;

  Map<int, Lote> _lotesById(BuildContext context) {
    final map = <int, Lote>{};
    for (final l in context.read<CeldaController>().lotes) {
      if (l.id != null) map[l.id!] = l;
    }
    return map;
  }

  Future<void> _imprimir() async {
    final lotes = _lotesById(context);
    setState(() => _generando = true);
    try {
      await Printing.layoutPdf(
        name: 'CeldaPro-etiquetas.pdf',
        onLayout: (_) => _service.buildSheet(
          celdas: widget.celdas,
          lotesById: lotes,
          formato: _formato,
        ),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  Future<void> _compartir() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generando = true);
    try {
      final bytes = await _service.buildSheet(
        celdas: widget.celdas,
        lotesById: _lotesById(context),
        formato: _formato,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'CeldaPro-etiquetas.pdf',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo generar el PDF: $e')),
      );
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.celdas.length;
    final hojas = total == 0 ? 0 : (total / _formato.porHoja).ceil();

    return Scaffold(
      appBar: AppBar(title: Text(widget.titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
        children: [
          Text(
            'Cada etiqueta lleva el código de barras con el identificador, un '
            'QR con la ficha completa de la celda y los datos en texto, para '
            'que la celda siga siendo identificable si la etiqueta se estropea.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text('Tamaño', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in LabelFormat.values)
                ChoiceChip(
                  label: Text('${f.label}\n${f.medida}'),
                  labelStyle: const TextStyle(fontSize: 11, height: 1.3),
                  selected: _formato == f,
                  onSelected: (_) => setState(() => _formato = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '$total ${total == 1 ? "celda" : "celdas"} · '
                      '${_formato.porHoja} por hoja · '
                      '$hojas ${hojas == 1 ? "hoja" : "hojas"}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.celdas.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Vista previa', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Así saldrá impresa la primera etiqueta.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Center(
              child: _EtiquetaPreview(
                celda: widget.celdas.first,
                lote: _lotesById(context)[widget.celdas.first.loteId],
                formato: _formato,
              ),
            ),
          ],
          if (total > 1) ...[
            const SizedBox(height: 12),
            Text(
              'Se incluirán las $total celdas seleccionadas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'compartir',
            onPressed: _generando ? null : _compartir,
            icon: const Icon(Icons.share_outlined),
            label: const Text('Compartir PDF'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'imprimir',
            onPressed: _generando || total == 0 ? null : _imprimir,
            icon: _generando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.print_outlined),
            label: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }
}

/// Reproduce en pantalla cómo quedará la etiqueta impresa.
class _EtiquetaPreview extends StatelessWidget {
  const _EtiquetaPreview({
    required this.celda,
    required this.lote,
    required this.formato,
  });

  final Celda celda;
  final Lote? lote;
  final LabelFormat formato;

  @override
  Widget build(BuildContext context) {
    const code = CodeService();
    final payload = payloadDeCelda(celda, lote: lote).encode();
    final barras = barcodeDeCelda(celda);

    // Proporción real del formato elegido, escalada a un ancho manejable.
    final ancho = 300.0;
    final alto = ancho * formato.altoMm / formato.anchoMm;
    final ladoQr = alto * (formato == LabelFormat.celda ? 0.42 : 0.5);

    final detalles = [
      [celda.marca, celda.modelo].whereType<String>().join(' '),
      [
        if (celda.capacidadNominalMah != null)
          '${celda.capacidadNominalMah!.toStringAsFixed(0)} mAh',
        if (celda.voltajeNominal != null) '${celda.voltajeNominal} V',
      ].join(' · '),
      if (lote != null) 'Lote ${lote!.codigo}',
    ].where((s) => s.trim().isNotEmpty).toList();

    return Container(
      width: ancho,
      height: alto,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: ladoQr,
                  height: ladoQr,
                  child: CustomPaint(
                    painter: CodePainter(code.qrDe(payload, lado: 100)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        celda.codigoInterno,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: Colors.black,
                        ),
                      ),
                      for (final d in detalles)
                        Text(
                          d,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.black87,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: alto * 0.22,
            child: CustomPaint(
              painter: CodePainter(code.barras(barras, ancho: 100, alto: 40)),
            ),
          ),
        ],
      ),
    );
  }
}
