import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/cell_code.dart';
import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/services/code_service.dart';

void main() {
  const code = CodeService();

  Celda celda({String codigo = 'C-0001'}) => Celda(
        codigoInterno: codigo,
        marca: 'Samsung',
        modelo: '25R (18650)',
        catalogRef: 'Samsung 25R (18650)',
        quimica: Chemistry.liIon,
        capacidadNominalMah: 2500,
        voltajeNominal: 3.6,
        irNominalMohm: 13,
        estado: CellState.classified,
        veredicto: Verdict.a,
        sohPct: 95.2,
        createdAt: DateTime(2026, 9, 20),
      );

  group('Payload de la etiqueta', () {
    test('codifica con el prefijo y la versión', () {
      final p = payloadDeCelda(celda());
      final texto = p.encode();
      expect(texto.startsWith('CELDAPRO|1|'), isTrue);
      expect(texto, contains('C-0001'));
      expect(texto, contains('Samsung'));
      expect(texto, contains('2500'));
    });

    test('ida y vuelta: codificar y decodificar conserva los datos', () {
      final original = payloadDeCelda(celda());
      final vuelta = CellPayload.decode(original.encode());

      expect(vuelta, isNotNull);
      expect(vuelta!.codigo, 'C-0001');
      expect(vuelta.marca, 'Samsung');
      expect(vuelta.modelo, '25R (18650)');
      expect(vuelta.referencia, 'Samsung 25R (18650)');
      expect(vuelta.quimica, 'Li-ion');
      expect(vuelta.capacidadMah, 2500);
      expect(vuelta.voltaje, 3.6);
      expect(vuelta.irMohm, 13);
      expect(vuelta.estado, 'Clasificada');
      expect(vuelta.veredicto, 'A');
      expect(vuelta.sohPct, 95.2);
    });

    test('incluye el código del lote', () {
      final p = payloadDeCelda(
        celda(),
        lote: Lote(
          id: 1,
          codigo: 'L-2026-09-A',
          fechaRecepcion: DateTime(2026, 9, 1),
        ),
      );
      expect(CellPayload.decode(p.encode())!.lote, 'L-2026-09-A');
    });

    test('una celda vacía no rompe la codificación', () {
      final p = payloadDeCelda(
        Celda(codigoInterno: 'C-9999', createdAt: DateTime(2026, 9, 20)),
      );
      final vuelta = CellPayload.decode(p.encode());
      expect(vuelta!.codigo, 'C-9999');
      expect(vuelta.marca, isNull);
      expect(vuelta.capacidadMah, isNull);
    });

    test('el separador dentro de un valor no rompe la lectura', () {
      final p = CellPayload(codigo: 'C-1', marca: 'Marca|Rara', modelo: 'X');
      final vuelta = CellPayload.decode(p.encode());
      expect(vuelta!.codigo, 'C-1');
      expect(vuelta.marca, 'Marca/Rara');
    });

    test('reconoce lo que es de CeldaPro y lo que no', () {
      expect(CellPayload.esPayload('CELDAPRO|1|C-1'), isTrue);
      expect(CellPayload.esPayload('https://ejemplo.com'), isFalse);
      expect(CellPayload.esPayload('C-0001'), isFalse);
    });

    test('un texto cualquiera no se interpreta como etiqueta', () {
      expect(CellPayload.decode('1234567890128'), isNull);
      expect(CellPayload.decode(''), isNull);
      expect(CellPayload.decode('CELDAPRO|9|C-1'), isNull,
          reason: 'versión desconocida');
      expect(CellPayload.decode('OTRA|1|C-1'), isNull);
    });

    test('el código de barras 1D lleva solo el identificador', () {
      expect(barcodeDeCelda(celda()), 'C-0001');
    });
  });

  group('Generación de códigos', () {
    test('el código 1D produce barras', () {
      final barras = code.barras('C-0001', ancho: 200, alto: 50);
      expect(barras, isNotEmpty);
    });

    test('el QR produce módulos', () {
      final modulos = code.qrDe('CELDAPRO|1|C-0001', lado: 200);
      expect(modulos, isNotEmpty);
    });

    test('un identificador normal se codifica bien', () {
      expect(code.codigo1DValido('C-0001'), isTrue);
      expect(code.codigo1DValido('L-2026-09-A'), isTrue);
    });

    test('texto vacío no se considera válido', () {
      expect(code.codigo1DValido(''), isFalse);
      expect(code.qrValido(''), isFalse);
    });

    test('la ficha completa de una celda cabe en el QR', () {
      final payload = payloadDeCelda(celda()).encode();
      expect(code.qrValido(payload), isTrue);
      // El QR admite mucha más información que el código de barras 1D.
      expect(payload.length, greaterThan(40));
    });
  });
}
