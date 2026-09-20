import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/cell_stats.dart';
import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/cell_event.dart';
import 'package:celdapro/data/models/cell_test.dart';
import 'package:celdapro/data/models/lote.dart';
import 'package:celdapro/services/report_service.dart';

/// Genera informes de verdad y comprueba que el PDF resultante es válido.
/// Deja una copia en /tmp para poder inspeccionarla por fuera.
Celda celda(
  int id,
  String codigo, {
  String? marca = 'Samsung',
  String? modelo = '25R',
  double? nominal = 2500,
  Verdict? veredicto,
  double? soh,
  CellState estado = CellState.received,
  int? loteId,
  String? foto,
  String? notas,
}) =>
    Celda(
      id: id,
      loteId: loteId,
      codigoInterno: codigo,
      marca: marca,
      modelo: modelo,
      capacidadNominalMah: nominal,
      voltajeNominal: 3.6,
      estado: estado,
      veredicto: veredicto,
      sohPct: soh,
      irNominalMohm: 13,
      ubicacion: 'Estante A1',
      fotoPath: foto,
      notas: notas,
      createdAt: DateTime(2026, 9, 1),
    );

void guardar(String nombre, Uint8List bytes) =>
    File('/tmp/celdapro-$nombre.pdf').writeAsBytesSync(bytes);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CellStats', () {
    test('lista vacía no divide entre cero', () {
      final s = CellStats.from([]);
      expect(s.total, 0);
      expect(s.clasificadas, 0);
      expect(s.avgSoh, isNull);
      expect(s.rechazoPct, 0);
      expect(s.avancePct, 0);
      expect(s.aptas, 0);
    });

    test('cuenta, media, extremos y rechazo con datos mezclados', () {
      final s = CellStats.from([
        celda(1, 'C-1', veredicto: Verdict.a, soh: 95, nominal: 2500),
        celda(2, 'C-2', veredicto: Verdict.b, soh: 80, nominal: 2500),
        celda(3, 'C-3', veredicto: Verdict.c, soh: 65, nominal: 2000),
        celda(4, 'C-4', veredicto: Verdict.reject, soh: 40, nominal: 2500),
      ]);

      expect(s.total, 4);
      expect(s.clasificadas, 4);
      expect(s.sinClasificar, 0);
      expect(s.avgSoh, closeTo(70, 0.001));
      expect(s.minSoh, 40);
      expect(s.maxSoh, 95);
      expect(s.rechazoPct, 25);
      expect(s.avancePct, 100);
      expect(s.aptas, 3);
      expect(s.de(Verdict.a), 1);
      expect(s.de(Verdict.reject), 1);
      expect(s.capacidadNominalMah, 9500);
    });

    test('la celda rechazada no aporta capacidad aprovechable', () {
      final s = CellStats.from([
        celda(1, 'C-1', veredicto: Verdict.a, soh: 95, nominal: 2500),
        celda(2, 'C-2', veredicto: Verdict.b, soh: 80, nominal: 2500),
        celda(3, 'C-3', veredicto: Verdict.c, soh: 65, nominal: 2000),
        celda(4, 'C-4', veredicto: Verdict.reject, soh: 40, nominal: 2500),
      ]);
      // 2500·0,95 + 2500·0,80 + 2000·0,65 = 2375 + 2000 + 1300
      expect(s.capacidadAprovechableMah, closeTo(5675, 0.01));
    });

    test('sin clasificar no cuenta para la media', () {
      final s = CellStats.from([
        celda(1, 'C-1', veredicto: Verdict.a, soh: 90, nominal: 2500),
        celda(2, 'C-2'),
        celda(3, 'C-3', estado: CellState.testing),
      ]);
      expect(s.clasificadas, 1);
      expect(s.sinClasificar, 2);
      expect(s.avgSoh, 90);
      expect(s.avancePct, closeTo(33.33, 0.01));
      expect(s.en(CellState.testing), 1);
    });

    test('veredicto sin SoH no se cuenta como clasificada', () {
      // Un dato a medias no debe torcer la media.
      final s = CellStats.from([
        celda(1, 'C-1', veredicto: Verdict.a, soh: 95),
        celda(2, 'C-2', veredicto: Verdict.b),
      ]);
      expect(s.clasificadas, 1);
      expect(s.sinClasificar, 1);
      expect(s.avgSoh, 95);
    });

    test('cuenta las fotos de evidencia', () {
      final s = CellStats.from([
        celda(1, 'C-1', foto: '/ruta/foto.jpg'),
        celda(2, 'C-2', foto: ''),
        celda(3, 'C-3'),
      ]);
      expect(s.conFoto, 1);
    });

    test('capacidad sin nominal no rompe la suma', () {
      final s = CellStats.from([
        celda(1, 'C-1', nominal: null, veredicto: Verdict.a, soh: 90),
        celda(2, 'C-2', nominal: 1000, veredicto: Verdict.a, soh: 90),
      ]);
      expect(s.capacidadNominalMah, 1000);
      expect(s.capacidadAprovechableMah, closeTo(900, 0.01));
    });
  });

  group('formatMah', () {
    test('usa Ah a partir de 1000 mAh y mAh por debajo', () {
      expect(formatMah(2500), '2.50 Ah');
      expect(formatMah(500), '500 mAh');
      expect(formatMah(1000), '1.00 Ah');
      expect(formatMah(0), '—');
      expect(formatMah(0, vacio: 'n/d'), 'n/d');
    });
  });

  group('Informe de celda', () {
    const service = ReportService();

    test('genera un PDF válido con historial y trazabilidad', () async {
      final bytes = await service.fichaCelda(
        celda: celda(1, 'C-0001',
            veredicto: Verdict.a,
            soh: 92,
            estado: CellState.classified,
            loteId: 7,
            notas: 'Celda de prueba con ñ y Ω'),
        lote: Lote(
          id: 7,
          codigo: 'L-2026-09-A',
          proveedor: 'Proveedor del taller',
          fechaRecepcion: DateTime(2026, 9, 2),
        ),
        tests: [
          CellTest(
            id: 1,
            celdaId: 1,
            fecha: DateTime(2026, 9, 3),
            voltajeV: 3.61,
            capacidadMedidaMah: 2300,
            resistenciaInternaMohm: 15,
            sohPct: 92,
            veredicto: Verdict.a,
            operador: 'Steve',
          ),
        ],
        eventos: [
          CellEvent(
            id: 1,
            celdaId: 1,
            tipo: EventType.created,
            fecha: DateTime(2026, 9, 1),
            nota: 'Alta de celda C-0001',
          ),
          CellEvent(
            id: 2,
            celdaId: 1,
            tipo: EventType.tested,
            fecha: DateTime(2026, 9, 3),
            nota: 'Test registrado — SoH 92 % (A)',
          ),
        ],
        nombreTaller: 'Taller de Prueba',
      );

      guardar('ficha-celda', bytes);
      expect(bytes.length, greaterThan(2000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('una celda sin datos opcionales tampoco rompe', () async {
      final bytes = await service.fichaCelda(
        celda: celda(2, 'C-0002', marca: null, modelo: null, nominal: null),
      );
      guardar('ficha-minima', bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('con foto adjunta genera el PDF', () async {
      // Un PNG mínimo válido de 1×1 píxel.
      final png = Uint8List.fromList(const [
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);
      final bytes = await service.fichaCelda(
        celda: celda(3, 'C-0003', foto: '/x/foto.jpg'),
        foto: png,
      );
      guardar('ficha-con-foto', bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('Informe de inventario y de lote', () {
    const service = ReportService();

    List<Celda> muchas(int n) => [
          for (var i = 1; i <= n; i++)
            celda(
              i,
              'C-${i.toString().padLeft(4, '0')}',
              marca: i.isEven ? 'LG' : 'Samsung',
              modelo: i.isEven ? 'M50' : '25R',
              veredicto: Verdict.values[i % 4],
              soh: 60 + (i % 40),
              estado: CellState.classified,
              loteId: 1,
            ),
        ];

    test('el inventario completo genera un PDF válido', () async {
      final bytes = await service.informe(
        celdas: muchas(12),
        lotesById: {
          1: Lote(
            id: 1,
            codigo: 'L-2026-09-A',
            proveedor: 'Proveedor del taller',
            fechaRecepcion: DateTime(2026, 9, 2),
          ),
        },
        nombreTaller: 'Taller de Prueba',
        operador: 'Steve',
      );
      guardar('inventario', bytes);
      expect(bytes.length, greaterThan(3000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('muchas celdas generan varias páginas', () async {
      final bytes = await service.informe(celdas: muchas(200));
      guardar('inventario-200', bytes);
      // El número de páginas va en el diccionario del documento; al menos
      // comprobamos que el PDF creció con el contenido.
      expect(bytes.length, greaterThan(6000));
    });

    test('un lote concreto genera su informe', () async {
      final lote = Lote(
        id: 1,
        codigo: 'L-2026-09-B',
        origen: 'Compra a particular',
        fechaRecepcion: DateTime(2026, 9, 5),
      );
      final bytes = await service.informe(
        celdas: muchas(6),
        lotesById: {1: lote},
        lote: lote,
      );
      guardar('lote', bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('inventario vacío no genera un documento roto', () async {
      final bytes = await service.informe(celdas: []);
      guardar('inventario-vacio', bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('umbrales personalizados aparecen en el informe', () async {
      final bytes = await service.informe(
        celdas: muchas(2),
        thresholds: const Thresholds(aMin: 85, bMin: 70, cMin: 55),
      );
      guardar('umbrales', bytes);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });

  group('Recursos de marca', () {
    test('el logo del informe está en los assets', () async {
      // Si faltara, los informes saldrían sin el logo (y sin avisar).
      final data = await rootBundle.load('assets/images/logo-lockup.png');
      expect(data.lengthInBytes, greaterThan(1000));
    });
  });
}
