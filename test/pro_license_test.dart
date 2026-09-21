import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/pro_license.dart';

/// Los códigos válidos de esta lista salen de `tools/generar_licencia.py`
/// (mismo algoritmo FNV-1a en Python y en Dart). Si alguna vez dejan de
/// coincidir, este test lo caza: es lo que garantiza que un código generado
/// para un taller se pueda activar en el teléfono sin conexión.
const _generadosEnPython = [
  'CPRO-TALL-ER01-C427',
  'CPRO-MOTO-RPRO-4D46',
  'CPRO-CELD-APRO-2FBE',
];

void main() {
  group('ProLicense', () {
    test('acepta los códigos generados por la herramienta', () {
      for (final codigo in _generadosEnPython) {
        expect(ProLicense.esCodigoValido(codigo), isTrue,
            reason: '$codigo debería ser válido');
      }
    });

    test('rechaza un código con la firma cambiada', () {
      expect(ProLicense.esCodigoValido('CPRO-TALL-ER01-0000'), isFalse);
      expect(ProLicense.esCodigoValido('CPRO-TALL-ER01-C428'), isFalse);
    });

    test('rechaza códigos mal formados', () {
      for (final malo in [
        null,
        '',
        'CPRO',
        'TALLER01',
        'CPRO-TALL-ER01', // falta la firma
        'CPRO-TAL-ER01-C427', // grupo corto
        'CPRO-TALL-ER01-C42', // firma corta
        'XXXX-TALL-ER01-C427', // prefijo equivocado
      ]) {
        expect(ProLicense.esCodigoValido(malo), isFalse,
            reason: '$malo no debería valer');
      }
    });

    test('tolera minúsculas, espacios y guiones largos', () {
      expect(ProLicense.esCodigoValido('cpro-tall-er01-c427'), isTrue);
      expect(ProLicense.esCodigoValido('  CPRO-TALL-ER01-C427  '), isTrue);
      expect(ProLicense.esCodigoValido('CPRO TALL ER01 C427'), isTrue);
      expect(ProLicense.esCodigoValido('CPRO—TALL—ER01—C427'), isTrue);
    });

    test('normalizar deja el código en su forma canónica', () {
      expect(ProLicense.normalizar(' cpro tall er01 c427 '),
          'CPRO-TALL-ER01-C427');
      expect(ProLicense.normalizar(null), '');
    });

    test('la firma es estable y de 4 dígitos hexadecimales', () {
      final f = ProLicense.firma('CPRO-TALL-ER01');
      expect(f, 'C427');
      expect(f, hasLength(4));
      expect(RegExp(r'^[0-9A-F]{4}$').hasMatch(f), isTrue);
      // El mismo texto da siempre la misma firma.
      expect(ProLicense.firma('CPRO-TALL-ER01'), f);
    });

    test('dos cuerpos distintos no dan la misma firma', () {
      expect(
        ProLicense.firma('CPRO-TALL-ER01'),
        isNot(ProLicense.firma('CPRO-TALL-ER02')),
      );
    });
  });
}
