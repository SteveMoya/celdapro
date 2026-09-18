import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/diagnostics.dart';
import 'package:celdapro/data/cell_catalog.dart';
import 'package:celdapro/data/models/celda.dart';

void main() {
  group('CellCatalog (datos portados de battery-tool)', () {
    test('contiene las 102 celdas del proyecto original', () {
      expect(CellCatalog.all.length, 102);
    });

    test('ninguna entrada tiene valores inválidos', () {
      for (final e in CellCatalog.all) {
        expect(e.name.trim(), isNotEmpty, reason: 'nombre vacío');
        expect(e.brand.trim(), isNotEmpty, reason: '${e.name}: marca vacía');
        expect(e.format.trim(), isNotEmpty, reason: '${e.name}: formato vacío');
        expect(e.capacityMah, greaterThan(0), reason: '${e.name}: capacidad');
        expect(e.voltage, greaterThan(0), reason: '${e.name}: voltaje');
        expect(e.irMohm, greaterThan(0), reason: '${e.name}: resistencia');
      }
    });

    test('las marcas y formatos se derivan bien', () {
      expect(CellCatalog.brands, contains('Samsung'));
      expect(CellCatalog.brands, contains('Molicel'));
      expect(CellCatalog.brands, contains('LG'));
      expect(CellCatalog.formats, contains('18650'));
      expect(CellCatalog.formats, contains('21700'));
      expect(CellCatalog.brands.length, greaterThan(20));
    });

    test('la ficha de una celda conocida es la correcta', () {
      final samsung25r =
          CellCatalog.all.firstWhere((e) => e.name == 'Samsung 25R (18650)');
      expect(samsung25r.brand, 'Samsung');
      expect(samsung25r.model, '25R (18650)');
      expect(samsung25r.format, '18650');
      expect(samsung25r.capacityMah, 2500);
      expect(samsung25r.voltage, 3.6);
      expect(samsung25r.irMohm, 13);
      expect(samsung25r.chemistry, Chemistry.liIon);
      expect(samsung25r.maxDischargeA, 20);
    });

    test('las químicas se mapean correctamente', () {
      final lfp = CellCatalog.all.where((e) => e.chemistry == Chemistry.lfp);
      final nimh = CellCatalog.all.where((e) => e.chemistry == Chemistry.nimh);
      final lto = CellCatalog.all.where((e) => e.chemistry == Chemistry.lto);

      expect(lfp, isNotEmpty);
      expect(nimh, isNotEmpty);
      expect(lto, isNotEmpty);
      // Las Eneloop AA son NiMH con 1.2 V.
      final eneloop = CellCatalog.all
          .firstWhere((e) => e.name.contains('Eneloop AA'));
      expect(eneloop.chemistry, Chemistry.nimh);
      expect(eneloop.voltage, 1.2);
    });

    test('shortName no repite la marca', () {
      final e = CellCatalog.all.firstWhere((e) => e.name.contains('Molicel'));
      expect(e.shortName.startsWith('Molicel'), isTrue);
      expect(e.shortName.contains('Molicel Molicel'), isFalse);
    });
  });

  group('CellCatalog.search', () {
    test('busca por marca', () {
      final r = CellCatalog.search('samsung');
      expect(r.length, greaterThan(5));
      expect(r.every((e) => e.brand == 'Samsung'), isTrue);
    });

    test('busca por modelo', () {
      final r = CellCatalog.search('25R');
      expect(r.any((e) => e.name.contains('Samsung 25R')), isTrue);
    });

    test('busca por formato', () {
      final r = CellCatalog.search('21700');
      expect(r, isNotEmpty);
      expect(r.every((e) => e.format == '21700'), isTrue);
    });

    test('busca por capacidad', () {
      final r = CellCatalog.search('3000');
      expect(r, isNotEmpty);
      expect(r.any((e) => e.capacityMah == 3000), isTrue);
    });

    test('filtra por química', () {
      final r = CellCatalog.search('', chemistry: Chemistry.lfp);
      expect(r, isNotEmpty);
      expect(r.every((e) => e.chemistry == Chemistry.lfp), isTrue);
    });

    test('filtra por formato', () {
      final r = CellCatalog.search('', format: '18650');
      expect(r, isNotEmpty);
      expect(r.every((e) => e.format == '18650'), isTrue);
    });

    test('combina texto y filtro', () {
      final r = CellCatalog.search('samsung', format: '18650');
      expect(r, isNotEmpty);
      expect(
        r.every((e) => e.format == '18650' && e.brand == 'Samsung'),
        isTrue,
      );
    });

    test('sin resultados devuelve lista vacía, no error', () {
      expect(CellCatalog.search('zzzznoexiste'), isEmpty);
    });

    test('query vacía devuelve todo', () {
      expect(CellCatalog.search('').length, CellCatalog.all.length);
    });
  });

  group('CellCatalog.matchByName', () {
    test('reconoce el nombre exacto', () {
      final e = CellCatalog.matchByName('Samsung 25R (18650)');
      expect(e?.name, 'Samsung 25R (18650)');
    });

    test('reconoce un texto parcial', () {
      final e = CellCatalog.matchByName('molicel p42a');
      expect(e?.brand, 'Molicel');
      expect(e?.name.contains('P42A'), isTrue);
    });

    test('texto muy corto o desconocido devuelve null', () {
      expect(CellCatalog.matchByName('ab'), isNull);
      expect(CellCatalog.matchByName('zzzznoexiste'), isNull);
    });
  });

  group('assessInternalResistance', () {
    test('normal hasta 1.3x la nominal', () {
      expect(
        assessInternalResistance(measuredMohm: 13, nominalMohm: 13).level,
        IrLevel.ok,
      );
      expect(
        assessInternalResistance(measuredMohm: 16.9, nominalMohm: 13).level,
        IrLevel.ok,
      );
    });

    test('elevada entre 1.3x y 2x', () {
      final r = assessInternalResistance(measuredMohm: 20, nominalMohm: 13);
      expect(r.level, IrLevel.high);
      expect(r.ratio, closeTo(1.54, 0.01));
      expect(r.level.isProblem, isTrue);
    });

    test('muy alta por encima de 2x', () {
      final r = assessInternalResistance(measuredMohm: 40, nominalMohm: 13);
      expect(r.level, IrLevel.veryHigh);
      expect(r.level.isProblem, isTrue);
    });

    test('sin referencia → unknown, sin lanzar', () {
      final r =
          assessInternalResistance(measuredMohm: 20, nominalMohm: null);
      expect(r.level, IrLevel.unknown);
      expect(r.ratio, isNull);
      expect(r.level.isProblem, isFalse);
    });

    test('nominal cero o negativa → unknown', () {
      expect(
        assessInternalResistance(measuredMohm: 20, nominalMohm: 0).level,
        IrLevel.unknown,
      );
      expect(
        assessInternalResistance(measuredMohm: 20, nominalMohm: -5).level,
        IrLevel.unknown,
      );
    });

    test('medición nula → unknown', () {
      expect(
        assessInternalResistance(measuredMohm: null, nominalMohm: 13).level,
        IrLevel.unknown,
      );
    });

    test('formatIrRatio formatea', () {
      expect(formatIrRatio(1.538), '1.5× la nominal');
      expect(formatIrRatio(null), '—');
    });
  });

  group('Celda con referencia de catálogo', () {
    test('la referencia sobrevive a toMap/fromMap', () {
      final celda = Celda(
        codigoInterno: 'C-0001',
        catalogRef: 'Samsung 25R (18650)',
        irNominalMohm: 13,
        capacidadNominalMah: 2500,
        createdAt: DateTime(2026, 9, 18),
      );
      final r = Celda.fromMap(celda.toMap());
      expect(r.catalogRef, 'Samsung 25R (18650)');
      expect(r.irNominalMohm, 13);
    });

    test('sin referencia quedan nulos', () {
      final celda = Celda(
        codigoInterno: 'C-0002',
        createdAt: DateTime(2026, 9, 18),
      );
      final r = Celda.fromMap(celda.toMap());
      expect(r.catalogRef, isNull);
      expect(r.irNominalMohm, isNull);
    });
  });
}
