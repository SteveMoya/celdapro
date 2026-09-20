import 'package:barcode/barcode.dart';
import 'package:flutter/material.dart';

/// Genera códigos de barras (1D) y QR (2D) como listas de barras.
///
/// Se generan una sola vez y se dibujan con el mismo criterio en pantalla y en
/// el PDF, de modo que lo que se ve en la vista previa es exactamente lo que
/// sale impreso.
class CodeService {
  const CodeService();

  /// Code 128: admite letras, números y guiones. Es el estándar para
  /// identificar productos y resiste bien el polvo y el desgaste.
  static final Barcode code128 = Barcode.code128();

  /// QR con corrección media (15 %): aguanta que la etiqueta se manche o se
  /// raye un poco sin dejar de leerse.
  static final Barcode qr =
      Barcode.qrCode(errorCorrectLevel: BarcodeQRCorrectionLevel.medium);

  /// Barras del código 1D para un identificador.
  List<BarcodeElement> barras(
    String data, {
    double ancho = 200,
    double alto = 50,
  }) =>
      code128
          .make(data, width: ancho, height: alto, drawText: false)
          .toList(growable: false);

  /// Módulos del QR para la ficha completa.
  List<BarcodeElement> qrDe(String data, {double lado = 200}) => qr
      .make(data, width: lado, height: lado, drawText: false)
      .toList(growable: false);

  /// ¿El texto se puede codificar en Code 128?
  ///
  /// Si no, la etiqueta se imprime sin código de barras en vez de fallar.
  bool codigo1DValido(String data) {
    if (data.isEmpty) return false;
    try {
      code128.make(data, width: 200, height: 50, drawText: false).toList();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// ¿El texto se puede codificar en QR?
  bool qrValido(String data) {
    if (data.isEmpty) return false;
    try {
      qr.make(data, width: 200, height: 200, drawText: false).toList();
      return true;
    } catch (_) {
      return false;
    }
  }
}

/// Dibuja barras de código (1D o QR) en un Canvas de Flutter.
///
/// Las barras blancas se omiten: el fondo ya es blanco y así se evita pintar
/// rectángulos innecesarios.
class CodePainter extends CustomPainter {
  const CodePainter(this.elementos, {this.color = Colors.black});

  final List<BarcodeElement> elementos;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (elementos.isEmpty) return;

    // Escala el dibujo para ocupar el espacio disponible sin deformarlo.
    var maxX = 0.0, maxY = 0.0;
    for (final e in elementos) {
      final r = e.right;
      final b = e.bottom;
      if (r > maxX) maxX = r;
      if (b > maxY) maxY = b;
    }
    if (maxX <= 0 || maxY <= 0) return;

    final escalas = Size(size.width / maxX, size.height / maxY);
    canvas.save();
    canvas.scale(escalas.width, escalas.height);

    final paint = Paint()..color = color;
    for (final e in elementos) {
      if (e is BarcodeBar) {
        if (!e.black) continue;
        canvas.drawRect(
          Rect.fromLTWH(e.left, e.top, e.width, e.height),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CodePainter old) =>
      old.elementos != elementos || old.color != color;
}
