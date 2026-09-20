import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes para los PDF.
///
/// El generador de PDF usa Helvetica por defecto, que **no** soporta acentos ni
/// símbolos como `Ω` o `·`: una etiqueta en español saldría con caracteres
/// inválidos. Por eso se incrusta Inter (la tipografía de la marca), que cubre
/// todo lo que la app imprime.
class PdfFonts {
  PdfFonts._(this.regular, this.bold, {this.fuenteDeMarca = true});

  final pw.Font regular;
  final pw.Font bold;

  /// ¿Se cargó la tipografía de la marca? Si es false se está usando la fuente
  /// por defecto del PDF, que no soporta acentos ni `Ω`.
  final bool fuenteDeMarca;

  static PdfFonts? _cache;

  /// Carga las fuentes una sola vez y las reutiliza.
  ///
  /// Si algo falla, cae a las fuentes por defecto en vez de dejar la app sin
  /// poder imprimir.
  static Future<PdfFonts> load() async {
    final cache = _cache;
    if (cache != null) return cache;

    try {
      final reg = await _load('assets/fonts/Inter-Regular.ttf');
      final neg = await _load('assets/fonts/Inter-Bold.ttf');
      return _cache = PdfFonts._(reg, neg);
    } catch (_) {
      return _cache = PdfFonts._(
        pw.Font.helvetica(),
        pw.Font.helveticaBold(),
        fuenteDeMarca: false,
      );
    }
  }

  static Future<pw.Font> _load(String ruta) async {
    final data = await rootBundle.load(ruta);
    return pw.Font.ttf(ByteData.sublistView(data));
  }

  /// Estilo con la fuente de la marca.
  pw.TextStyle style({
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
  }) =>
      pw.TextStyle(
        font: bold ? this.bold : regular,
        fontSize: fontSize,
        color: color,
      );
}
