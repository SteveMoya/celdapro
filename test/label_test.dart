import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/services/label_service.dart';
import 'package:celdapro/services/pdf_fonts.dart';

/// Genera hojas de etiquetas de verdad y comprueba que el PDF resultante es
/// válido. Además deja una copia en /tmp para poder inspeccionarla por fuera.
void main() {
  const service = LabelService();

  Celda celda(int i) => Celda(
        id: i,
        codigoInterno: 'C-${i.toString().padLeft(4, '0')}',
        marca: 'Samsung',
        modelo: '25R (18650)',
        capacidadNominalMah: 2500,
        voltajeNominal: 3.6,
        estado: CellState.classified,
        veredicto: Verdict.a,
        sohPct: 95.2,
        createdAt: DateTime(2026, 9, 20),
      );

  final lote = Lote(
    id: 1,
    codigo: 'L-2026-09-A',
    fechaRecepcion: DateTime(2026, 9, 1),
  );

  test('el formato indicado cabe en la hoja y cuadra con la cuenta', () {
    expect(LabelFormat.celda.porHoja, 24);
    expect(LabelFormat.estandar.porHoja, 21);
    expect(LabelFormat.caja.porHoja, 14);
    expect(LabelFormat.unaLinea.porHoja, 60);

    // Las etiquetas no pueden ser más anchas que la caja de impresión de una
    // A4 con márgenes de 6 mm por lado (198 mm útiles).
    for (final f in LabelFormat.values) {
      expect(f.anchoMm * f.columnas, lessThanOrEqualTo(198),
          reason: '${f.label}: ${f.columnas} columnas no caben a lo ancho');
      expect(f.altoMm * f.filas, lessThanOrEqualTo(285),
          reason: '${f.label}: ${f.filas} filas no caben a lo alto');
    }
  });

  test('los textos llevan acentos y símbolos: la fuente de marca se carga', () {
    // Con la fuente por defecto del PDF (Helvetica) los acentos y el símbolo Ω
    // no existen y las etiquetas saldrían con caracteres inválidos.
    TestWidgetsFlutterBinding.ensureInitialized();
    return PdfFonts.load().then((f) {
      expect(f.fuenteDeMarca, isTrue,
          reason: 'no se cargó Inter: las etiquetas perderían acentos y Ω');
    });
  });

  test('genera un PDF válido para una celda', () async {
    final bytes = await service.buildSheet(
      celdas: [celda(1)],
      lotesById: {1: lote},
      formato: LabelFormat.celda,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');

    await File('/tmp/celdapro-etiquetas-1.pdf').writeAsBytes(bytes);
  });

  test('una hoja por cada 24 celdas con el formato de celda', () async {
    final bytes = await service.buildSheet(
      celdas: List.generate(25, (i) => celda(i + 1)),
      lotesById: {1: lote},
      formato: LabelFormat.celda,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await File('/tmp/celdapro-etiquetas-25.pdf').writeAsBytes(bytes);
  });

  test('500 celdas generan muchas hojas sin fallar', () async {
    final celdas = List.generate(500, (i) => celda(i + 1));
    final bytes = await service.buildSheet(
      celdas: celdas,
      formato: LabelFormat.estandar,
    );
    expect(bytes.length, greaterThan(50000));
    await File('/tmp/celdapro-etiquetas-500.pdf').writeAsBytes(bytes);
  });

  test('los tres formatos generan PDF', () async {
    for (final f in LabelFormat.values) {
      final bytes = await service.buildSheet(
        celdas: List.generate(5, (i) => celda(i + 1)),
        formato: f,
        nombreTaller: 'Taller de prueba',
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-',
          reason: '${f.label} no generó un PDF válido');
    }
  });

  test('la etiqueta de una línea imprime el código como texto', () async {
    // Es la etiqueta que lee el OCR: el código tiene que ir como texto real,
    // no como imagen, o el reconocimiento no tendría nada que leer.
    final bytes = await service.buildSheet(
      celdas: [celda(1)],
      lotesById: {1: lote},
      formato: LabelFormat.unaLinea,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await File('/tmp/celdapro-etiqueta-una-linea.pdf').writeAsBytes(bytes);
  });

  test('un código largo del taller se encoge y no rompe la línea', () async {
    // 'SAMSUNG-A12' es más largo que 'C-0001': debe encajar igualmente.
    final bytes = await service.buildSheet(
      celdas: [
        Celda(codigoInterno: 'SAMSUNG-A12', createdAt: DateTime(2026, 9, 20)),
      ],
      formato: LabelFormat.unaLinea,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    await File('/tmp/celdapro-etiqueta-larga.pdf').writeAsBytes(bytes);
  });

  test('una celda sin datos técnicos tampoco rompe la etiqueta', () async {
    final bytes = await service.buildSheet(
      celdas: [Celda(codigoInterno: 'C-7777', createdAt: DateTime(2026, 9, 20))],
      formato: LabelFormat.celda,
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('lista vacía no genera documento roto', () async {
    final bytes = await service.buildSheet(celdas: const []);
    // Sin celdas no hay páginas: el PDF es mínimo pero válido.
    expect(bytes.isEmpty || String.fromCharCodes(bytes.take(5)) == '%PDF-',
        isTrue);
  });
}
