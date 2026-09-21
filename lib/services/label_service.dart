import 'dart:typed_data';

import 'package:barcode/barcode.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/cell_code.dart';
import '../data/models/celda.dart';
import '../data/models/lote.dart';
import 'code_service.dart';
import 'pdf_fonts.dart';

/// Tamaños de hoja de etiquetas disponibles.
enum LabelFormat {
  celda('Etiqueta de celda', '50 × 30 mm', 50, 30, 3, 8),
  estandar('Estándar', '63.5 × 38.1 mm', 63.5, 38.1, 3, 7),
  caja('Etiqueta de caja', '99 × 38 mm', 99, 38, 2, 7),

  /// Tira de una sola línea para pegar en cada celda que se está restaurando.
  ///
  /// Lleva el código en texto grande —para leerlo de un vistazo y para que lo
  /// lea el OCR— y el código de barras al lado, por si se prefiere escanear.
  unaLinea('Etiqueta en una línea', '50 × 12 mm', 50, 12, 3, 20);

  const LabelFormat(this.label, this.medida, this.anchoMm, this.altoMm,
      this.columnas, this.filas);

  final String label;
  final String medida;
  final double anchoMm;
  final double altoMm;
  final int columnas;
  final int filas;

  /// Cuántas etiquetas caben en una hoja A4.
  int get porHoja => columnas * filas;
}

/// Genera hojas de etiquetas en PDF: código de barras 1D con el identificador,
/// QR con la ficha completa y los datos en texto legible.
class LabelService {
  const LabelService();

  static const _code = CodeService();

  /// Construye el PDF con una etiqueta por celda.
  Future<Uint8List> buildSheet({
    required List<Celda> celdas,
    Map<int, Lote> lotesById = const {},
    LabelFormat formato = LabelFormat.celda,
    String? nombreTaller,
  }) async {
    final fuentes = await PdfFonts.load();
    final doc = pw.Document(title: 'Etiquetas de celdas — CeldaPro');
    final porHoja = formato.porHoja;

    for (var i = 0; i < celdas.length; i += porHoja) {
      final trozo = celdas.skip(i).take(porHoja).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(6 * PdfPageFormat.mm),
          build: (context) => pw.Wrap(
            spacing: 0,
            runSpacing: 0,
            children: [
              for (final celda in trozo)
                _etiqueta(
                  celda,
                  lotesById[celda.loteId],
                  formato,
                  nombreTaller,
                  fuentes,
                ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  /// Una etiqueta individual.
  pw.Widget _etiqueta(
    Celda celda,
    Lote? lote,
    LabelFormat formato,
    String? nombreTaller,
    PdfFonts fuentes,
  ) {
    final payload = payloadDeCelda(celda, lote: lote);
    final qrData = payload.encode();
    final barrasData = barcodeDeCelda(celda);

    if (formato == LabelFormat.unaLinea) {
      return _unaLinea(celda, barrasData, fuentes);
    }

    final ancho = formato.anchoMm * PdfPageFormat.mm;
    final alto = formato.altoMm * PdfPageFormat.mm;
    final compacta = formato == LabelFormat.celda;

    // Tamaños proporcionales al alto de la etiqueta, para que las tres
    // medidas se vean bien sin recalcular a mano.
    final ladoQr = compacta ? alto * 0.52 : alto * 0.62;
    final altoBarras = compacta ? 7 * PdfPageFormat.mm : 9 * PdfPageFormat.mm;

    final detalles = <String>[
      if (celda.marca != null || celda.modelo != null)
        [celda.marca, celda.modelo].whereType<String>().join(' '),
      [
        if (celda.capacidadNominalMah != null)
          '${celda.capacidadNominalMah!.toStringAsFixed(0)} mAh',
        if (celda.voltajeNominal != null) '${celda.voltajeNominal} V',
      ].join(' · '),
      if (lote != null) 'Lote ${lote.codigo}',
    ].where((s) => s.trim().isNotEmpty).toList();

    return pw.Container(
      width: ancho,
      height: alto,
      padding: const pw.EdgeInsets.all(2.2 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(
                  width: ladoQr,
                  height: ladoQr,
                  child: _qr(qrData, ladoQr),
                ),
                pw.SizedBox(width: 2.2 * PdfPageFormat.mm),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        celda.codigoInterno,
                        style: fuentes.style(
                          fontSize: compacta ? 13 : 15,
                          bold: true,
                        ),
                      ),
                      pw.SizedBox(height: 0.8 * PdfPageFormat.mm),
                      for (final d in detalles)
                        pw.Text(
                          d,
                          style: fuentes.style(
                            fontSize: 7.5,
                            color: PdfColors.grey800,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 1.4 * PdfPageFormat.mm),
          pw.SizedBox(
            width: double.infinity,
            height: altoBarras,
            child: _barras(barrasData),
          ),
          if (nombreTaller != null)
            pw.Text(
              nombreTaller,
              style: fuentes.style(fontSize: 5.5, color: PdfColors.grey600),
            ),
        ],
      ),
    );
  }

  /// Etiqueta de una sola línea: el código en grande más el código de barras.
  ///
  /// Pensada para pegar en cada celda que se está restaurando. El código va
  /// como **texto real** (no como imagen) y con cuerpo grande, para que lo lea
  /// tanto una persona de un vistazo como el OCR de la app.
  ///
  /// El texto va dentro de un `FittedBox` con `scaleDown`: un código corto
  /// (`C-0001`) sale al cuerpo grande, y uno largo del taller se encoge lo
  /// justo para caber en la línea en vez de partirse en dos.
  pw.Widget _unaLinea(Celda celda, String barrasData, PdfFonts fuentes) {
    final ancho = LabelFormat.unaLinea.anchoMm * PdfPageFormat.mm;
    final alto = LabelFormat.unaLinea.altoMm * PdfPageFormat.mm;
    const margen = 1.2 * PdfPageFormat.mm;
    final altoBarras = alto - margen * 2;

    return pw.Container(
      width: ancho,
      height: alto,
      padding: const pw.EdgeInsets.all(margen),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // El código de barras ocupa algo más de un tercio: cuanto más ancho,
          // más separadas van las barras y mejor las resuelve la cámara. El
          // resto es para el código en texto, que es lo que lee el OCR.
          pw.SizedBox(
            width: ancho * 0.38,
            height: altoBarras,
            child: _barras(barrasData),
          ),
          pw.SizedBox(width: 1.5 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                celda.codigoInterno,
                style: fuentes.style(fontSize: 14, bold: true),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// QR dibujado como rectángulos (sin depender del soporte SVG del PDF).
  pw.Widget _qr(String data, double lado) {
    if (!_code.qrValido(data)) {
      return pw.Center(
        child: pw.Text('QR no disponible', style: const pw.TextStyle(fontSize: 6)),
      );
    }
    final elementos = _code.qrDe(data, lado: 100);
    return pw.CustomPaint(
      size: PdfPoint(lado, lado),
      painter: (canvas, size) {
        canvas.setFillColor(PdfColors.black);
        for (final e in elementos) {
          if (e is BarcodeBar && e.black) {
            // El PDF tiene el origen abajo a la izquierda: se invierte la Y.
            canvas.drawRect(
              e.left * size.x / 100,
              size.y - (e.top + e.height) * size.y / 100,
              e.width * size.x / 100,
              e.height * size.y / 100,
            );
          }
        }
        canvas.fillPath();
      },
    );
  }

  /// Código de barras 1D con el identificador de la celda.
  ///
  /// Los elementos vienen en un espacio de 0..100 y hay que **escalarlos** a la
  /// caja disponible, igual que hace `CodePainter` en pantalla. Dibujarlos en
  /// bruto (lo que se hacía antes) los sacaba a 100 pt —unos 36 mm— de ancho
  /// ignorando el tamaño pedido: la etiqueta impresa no coincidía con la vista
  /// previa de la app y el código salía cortado por el borde.
  pw.Widget _barras(String data) {
    if (!_code.codigo1DValido(data)) return pw.SizedBox();
    final elementos = _code.barras(data, ancho: 100, alto: 100);

    // El alto real de las barras no es 100: se mide para escalar igual que la
    // vista previa, en vez de estirar de más.
    var maxX = 0.0, maxY = 0.0;
    for (final e in elementos) {
      if (e.right > maxX) maxX = e.right;
      if (e.bottom > maxY) maxY = e.bottom;
    }
    if (maxX <= 0 || maxY <= 0) return pw.SizedBox();

    return pw.CustomPaint(
      size: PdfPoint(100, 100),
      painter: (canvas, size) {
        canvas.setFillColor(PdfColors.black);
        for (final e in elementos) {
          if (e is BarcodeBar && e.black) {
            canvas.drawRect(
              e.left * size.x / maxX,
              size.y - (e.top + e.height) * size.y / maxY,
              e.width * size.x / maxX,
              e.height * size.y / maxY,
            );
          }
        }
        canvas.fillPath();
      },
    );
  }
}
