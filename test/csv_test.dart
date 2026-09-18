import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/services/csv_service.dart';

void main() {
  const service = CsvService();

  group('buildCsv', () {
    test('incluye encabezados y una fila por celda', () {
      final celdas = [
        Celda(
          id: 1,
          codigoInterno: 'C-0001',
          marca: 'Samsung',
          modelo: 'INR18650',
          capacidadNominalMah: 2500,
          estado: CellState.classified,
          veredicto: Verdict.a,
          sohPct: 94.0,
          createdAt: DateTime(2026, 9, 17),
        ),
      ];
      final csv = service.buildCsv(celdas: celdas, lotesById: const {});
      final lineas = csv.trim().split('\n');
      expect(lineas.length, 2);
      expect(lineas.first, contains('codigo_interno'));
      expect(lineas.last, contains('C-0001'));
      expect(lineas.last, contains('Samsung'));
    });

    test('incluye el código del lote cuando existe', () {
      final celdas = [
        Celda(
          loteId: 5,
          codigoInterno: 'C-0002',
          createdAt: DateTime(2026, 9, 17),
        ),
      ];
      final csv = service.buildCsv(
        celdas: celdas,
        lotesById: {
          5: Lote(
            id: 5,
            codigo: 'L-2026-09-A',
            fechaRecepcion: DateTime(2026, 9, 1),
          ),
        },
      );
      expect(csv, contains('L-2026-09-A'));
    });
  });

  group('parseCsv', () {
    test('lee celdas correctamente', () {
      const input = 'codigo_interno,marca,capacidad_nominal_mah,quimica,estado\n'
          'C-0100,LG,3000,LFP,Recepcionada\n'
          'C-0101,Samsung,2500,Li-ion,En test\n';

      final r = service.parseCsv(input);
      expect(r.celdas.length, 2);
      expect(r.errors, isEmpty);

      final primera = r.celdas.first;
      expect(primera.codigoInterno, 'C-0100');
      expect(primera.marca, 'LG');
      expect(primera.capacidadNominalMah, 3000);
      expect(primera.quimica, Chemistry.lfp);
      expect(primera.estado, CellState.received);

      expect(r.celdas[1].quimica, Chemistry.liIon);
      expect(r.celdas[1].estado, CellState.testing);
    });

    test('tolera comas decimales', () {
      const input = 'codigo_interno,capacidad_nominal_mah,soh_pct\n'
          'C-0200,2500,87,5\n';
      final r = service.parseCsv(input);
      expect(r.celdas.single.capacidadNominalMah, 2500);
    });

    test('lee el veredicto si viene', () {
      const input = 'codigo_interno,veredicto,soh_pct\nC-0300,A,95\n';
      final r = service.parseCsv(input);
      expect(r.celdas.single.veredicto, Verdict.a);
      expect(r.celdas.single.sohPct, 95);
    });

    test('falla claro si falta la columna obligatoria', () {
      const input = 'marca,modelo\nLG,ABC\n';
      final r = service.parseCsv(input);
      expect(r.celdas, isEmpty);
      expect(r.errors.first, contains('codigo_interno'));
    });

    test('reporta filas sin código como error, no las importa', () {
      const input = 'codigo_interno,marca\n,C-100\nC-0400,LG\n';
      final r = service.parseCsv(input);
      expect(r.celdas.length, 1);
      expect(r.errors.length, 1);
      expect(r.errors.first, contains('Fila 2'));
    });

    test('ignora líneas vacías', () {
      const input = 'codigo_interno\nC-0500\n\n\nC-0501\n';
      final r = service.parseCsv(input);
      expect(r.celdas.length, 2);
      expect(r.errors, isEmpty);
    });

    test('archivo vacío devuelve error', () {
      final r = service.parseCsv('');
      expect(r.celdas, isEmpty);
      expect(r.errors, isNotEmpty);
    });

    test('ida y vuelta: exportar y reimportar conserva los datos', () {
      final original = [
        Celda(
          codigoInterno: 'C-0001',
          marca: 'Samsung',
          capacidadNominalMah: 2500,
          estado: CellState.classified,
          veredicto: Verdict.a,
          sohPct: 94.0,
          createdAt: DateTime(2026, 9, 17),
        ),
        Celda(
          codigoInterno: 'C-0002',
          marca: 'LG',
          capacidadNominalMah: 3000,
          estado: CellState.rejected,
          veredicto: Verdict.reject,
          sohPct: 42.0,
          createdAt: DateTime(2026, 9, 17),
        ),
      ];

      final csv = service.buildCsv(celdas: original, lotesById: const {});
      final vuelta = service.parseCsv(csv);

      expect(vuelta.celdas.length, 2);
      expect(vuelta.celdas[0].codigoInterno, 'C-0001');
      expect(vuelta.celdas[0].marca, 'Samsung');
      expect(vuelta.celdas[0].sohPct, 94.0);
      expect(vuelta.celdas[0].veredicto, Verdict.a);
      expect(vuelta.celdas[1].veredicto, Verdict.reject);
      expect(vuelta.celdas[1].estado, CellState.rejected);
    });
  });
}
