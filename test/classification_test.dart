import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/classification.dart';

void main() {
  group('computeSoh', () {
    test('calcula el porcentaje correctamente', () {
      expect(computeSoh(measuredMah: 2500, nominalMah: 2500), 100.0);
      expect(computeSoh(measuredMah: 2000, nominalMah: 2500), 80.0);
      expect(computeSoh(measuredMah: 1500, nominalMah: 2500), 60.0);
    });

    test('devuelve null si faltan datos', () {
      expect(computeSoh(measuredMah: null, nominalMah: 2500), isNull);
      expect(computeSoh(measuredMah: 2000, nominalMah: null), isNull);
    });

    test('devuelve null con nominal no válida', () {
      expect(computeSoh(measuredMah: 2000, nominalMah: 0), isNull);
      expect(computeSoh(measuredMah: 2000, nominalMah: -100), isNull);
    });

    test('devuelve null con medida no válida (no cero)', () {
      expect(computeSoh(measuredMah: 0, nominalMah: 2500), isNull);
      expect(computeSoh(measuredMah: -5, nominalMah: 2500), isNull);
    });
  });

  group('classifySoh con umbrales por defecto (90/75/60)', () {
    test('A en el límite y por encima', () {
      expect(classifySoh(100), Verdict.a);
      expect(classifySoh(90), Verdict.a);
      expect(classifySoh(95.5), Verdict.a);
    });

    test('B entre 75 y 89.9', () {
      expect(classifySoh(89.9), Verdict.b);
      expect(classifySoh(75), Verdict.b);
    });

    test('C entre 60 y 74.9', () {
      expect(classifySoh(74.9), Verdict.c);
      expect(classifySoh(60), Verdict.c);
    });

    test('rechazo por debajo de 60', () {
      expect(classifySoh(59.9), Verdict.reject);
      expect(classifySoh(0), Verdict.reject);
    });
  });

  group('classifyByCapacity', () {
    test('celda al 92 % de su nominal → A', () {
      final r = classifyByCapacity(measuredMah: 2300, nominalMah: 2500);
      expect(r.verdict, Verdict.a);
      expect(r.soh, closeTo(92.0, 0.001));
      expect(r.computed, isTrue);
    });

    test('celda al 50 % → rechazo con SoH calculado', () {
      final r = classifyByCapacity(measuredMah: 1250, nominalMah: 2500);
      expect(r.verdict, Verdict.reject);
      expect(r.soh, closeTo(50.0, 0.001));
    });

    test('capacidad medida 0 → rechazo con motivo (celda muerta)', () {
      final r = classifyByCapacity(measuredMah: 0, nominalMah: 2500);
      expect(r.verdict, Verdict.reject);
      expect(r.soh, isNull);
      expect(r.reason, isNotNull);
      expect(r.computed, isFalse);
    });

    test('sin datos → rechazo con motivo, no excepción', () {
      final r = classifyByCapacity(measuredMah: null, nominalMah: null);
      expect(r.verdict, Verdict.reject);
      expect(r.computed, isFalse);
      expect(r.reason, isNotNull);
    });
  });

  group('Thresholds', () {
    test('sanitized ordena y limita a 0-100', () {
      const t = Thresholds(aMin: 150, bMin: 20, cMin: -10);
      final s = t.sanitized();
      expect(s.aMin, lessThanOrEqualTo(100));
      expect(s.aMin, greaterThanOrEqualTo(s.bMin));
      expect(s.bMin, greaterThanOrEqualTo(s.cMin));
      expect(s.cMin, greaterThanOrEqualTo(0));
    });

    test('sanitized no deja invertidos los umbrales', () {
      const t = Thresholds(aMin: 50, bMin: 80, cMin: 70);
      final s = t.sanitized();
      expect(s.aMin, greaterThanOrEqualTo(s.bMin));
      expect(s.bMin, greaterThanOrEqualTo(s.cMin));
    });

    test('sobrevive a toMap/fromMap', () {
      const t = Thresholds(aMin: 95, bMin: 80, cMin: 65);
      expect(Thresholds.fromMap(t.toMap()), t);
    });

    test('umbrales personalizados cambian el veredicto', () {
      const strict = Thresholds(aMin: 95, bMin: 85, cMin: 70);
      expect(classifySoh(92, strict), Verdict.b); // con 90 sería A
      expect(classifySoh(65, strict), Verdict.reject); // con 60 sería C
    });
  });

  group('Verdict', () {
    test('fromName/fromCode', () {
      expect(Verdict.fromName('a'), Verdict.a);
      expect(Verdict.fromCode('Rechazo'), Verdict.reject);
      expect(Verdict.fromCode('B'), Verdict.b);
      expect(Verdict.fromName('desconocido'), Verdict.reject);
    });

    test('isRejected', () {
      expect(Verdict.reject.isRejected, isTrue);
      expect(Verdict.a.isRejected, isFalse);
    });
  });

  group('formatSoh', () {
    test('formatea con un decimal', () {
      expect(formatSoh(87.44), '87.4 %');
      expect(formatSoh(null), '—');
    });
  });
}
