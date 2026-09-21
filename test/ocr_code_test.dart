import 'package:celdapro/core/ocr_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizarTextoOcr', () {
    test('pasa a mayúsculas y quita acentos', () {
      expect(normalizarTextoOcr('Etiqueta de celda'), 'ETIQUETA DE CELDA');
      expect(normalizarTextoOcr('Clasificación'), 'CLASIFICACION');
    });

    test('unifica los separadores que confunde el OCR', () {
      expect(normalizarTextoOcr('C—0001'), 'C-0001');
      expect(normalizarTextoOcr('C_0001'), 'C-0001');
      expect(normalizarTextoOcr('C:0001'), 'C-0001');
      expect(normalizarTextoOcr('C.0001'), 'C-0001');
    });

    test('colapsa los espacios sobrantes', () {
      expect(normalizarTextoOcr('  C    0001 \n'), 'C 0001');
    });
  });

  group('codigosCandidatos', () {
    test('lee un código limpio', () {
      final c = codigosCandidatos('C-0001');
      expect(c.first, 'C-0001');
      expect(c, contains('C0001'));
    });

    test('corrige las letras que el OCR confunde con dígitos', () {
      // O por 0, I por 1, S por 5, B por 8, Z por 2.
      expect(codigosCandidatos('C-0OO1').first, 'C-0001');
      expect(codigosCandidatos('C-00OI').first, 'C-0001');
      expect(codigosCandidatos('C-OOSI').first, 'C-0051');
      expect(codigosCandidatos('C-OOBZ').first, 'C-0082');
    });

    test('tolera que el OCR pierda el guion', () {
      expect(codigosCandidatos('C0001').first, 'C-0001');
      expect(codigosCandidatos('C 0001').first, 'C-0001');
    });

    test('acepta minúsculas', () {
      expect(codigosCandidatos('c-0001').first, 'C-0001');
    });

    test('no inventa códigos a partir de texto normal', () {
      // Este es el caso que importa: una etiqueta lleva marca, capacidad y
      // lote además del código. Nada de eso debe confundirse con un código.
      expect(codigosCandidatos('Lote 7 / Samsung'), isEmpty);
      expect(codigosCandidatos('SAMSUNG 25R'), isEmpty);
      expect(codigosCandidatos('Capacidad medida'), isEmpty);
    });

    test('el código gana a los números sueltos de la misma etiqueta', () {
      // Una etiqueta estándar imprime "C-0001" y también "2500 mAh".
      // El código tiene que salir primero.
      final c = codigosCandidatos('C-0001\n2500 mAh · 3.7 V');
      expect(c.first, 'C-0001');
      // Los números sueltos quedan como último recurso, no delante.
      expect(c.indexOf('2500'), greaterThan(0));
    });

    test('saca el código de un texto con varias líneas', () {
      final c = codigosCandidatos('TALLER EL MOTOR\nC-0042\nSamsung 25R');
      expect(c.first, 'C-0042');
    });

    test('acepta códigos del taller que no siguen el patrón', () {
      final c = codigosCandidatos('SAMSUNG-A12');
      expect(c, contains('SAMSUNG-A12'));
    });

    test('lee el código de una etiqueta impresa pasada por OCR de verdad', () {
      // Estos textos NO son inventados: son lo que devolvió un OCR real
      // (tesseract) sobre la etiqueta de una línea renderizada a 300 ppp.
      // Fíjate en el ruido: el OCR intenta leer también el código de barras.
      expect(codigosCandidatos('I MMIIIII| c-0001').first, 'C-0001');
      expect(codigosCandidatos('SAMSUNG-A12').first, 'SAMSUNG-A12');
    });

    test('no repite candidatos', () {
      final c = codigosCandidatos('C-0001 C-0001');
      expect(c.where((x) => x == 'C-0001').length, 1);
    });

    test('descarta el ruido de menos de tres caracteres', () {
      expect(codigosCandidatos('a 12'), isEmpty);
    });
  });

  group('distancia', () {
    test('cuenta los cambios entre dos cadenas', () {
      expect(distancia('C-0001', 'C-0001'), 0);
      expect(distancia('C-0001', 'C-0002'), 1);
      expect(distancia('C-0001', 'C-0011'), 1);
      expect(distancia('', 'ABC'), 3);
      expect(distancia('ABC', ''), 3);
    });
  });

  group('sugerencias', () {
    test('propone el código correcto cuando el OCR leyó mal una letra', () {
      // "C-0OO1" se corrige a "C-0001", que no existe; el inventario tiene
      // "C-0002". Debe proponerlo.
      final s = sugerencias('C-0OO1', ['C-0002', 'C-0003', 'C-9999']);
      expect(s.first, 'C-0002');
      expect(s, isNot(contains('C-9999')));
    });

    test('ordena por parecido y descarta lo que no se parece', () {
      // Distancias distintas a propósito: 'C-0001X' está a 1 cambio,
      // 'C-0042' a 2 y 'C-7777' a 4 (fuera de la tolerancia de 6 caracteres).
      final s = sugerencias('C-0001', ['C-7777', 'C-0042', 'C-0001X']);
      expect(s.first, 'C-0001X');
      expect(s, contains('C-0042'));
      expect(s, isNot(contains('C-7777')));
    });

    test('el orden es siempre el mismo cuando hay empate', () {
      // 'C-0002' y 'C-0003' están los dos a un cambio: debe ganar el primero
      // por orden alfabético, no por casualidad del orden de entrada.
      final existentes = ['C-0003', 'C-0002'];
      expect(sugerencias('C-0001', existentes).first, 'C-0002');
      expect(sugerencias('C-0001', existentes.reversed).first, 'C-0002');
    });

    test('no propone nada si lo leído no se parece a ningún código', () {
      expect(sugerencias('SAMSUNG', ['C-0001', 'C-0002']), isEmpty);
      expect(sugerencias('', ['C-0001']), isEmpty);
    });

    test('respeta el máximo de sugerencias', () {
      final existentes = List.generate(20, (i) => 'C-000$i');
      expect(sugerencias('C-0001', existentes, maximo: 2).length, 2);
    });
  });
}
