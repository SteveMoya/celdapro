// Comprueba qué fuentes puede usar el generador de PDF.
//
// El PDF por defecto usa Helvetica, que NO soporta acentos ni símbolos como
// Ω o ·: las etiquetas en español saldrían mal. Este script dice qué fuentes
// del sistema se pueden incrustar de verdad.
//
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

Future<bool> probar(String ruta) async {
  try {
    final bytes = await File(ruta).readAsBytes();
    final font = pw.Font.ttf(ByteData.sublistView(bytes));
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Column(
          children: [
            // Acentos y símbolos que usa una etiqueta real.
            pw.Text('Capacidad 2 380 mAh · 3.6 V · 13 mΩ · Rechazada ñ á é í ó ú',
                style: pw.TextStyle(font: font, fontSize: 10)),
          ],
        ),
      ),
    );
    final out = await doc.save();
    File('/tmp/probe-${ruta.split('/').last}.pdf').writeAsBytesSync(out);
    return out.length > 500;
  } catch (e) {
    print('    error: $e');
    return false;
  }
}

void main() async {
  final candidatos = [
    '/tmp/inter.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',
    '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',
  ];

  for (final c in candidatos) {
    final existe = File(c).existsSync();
    if (!existe) {
      print('  -- $c (no existe)');
      continue;
    }
    final ok = await probar(c);
    print('  ${ok ? "OK  " : "FALLA"} $c');
  }
}
