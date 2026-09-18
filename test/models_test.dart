import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/cell_event.dart';
import 'package:celdapro/data/models/cell_test.dart';
import 'package:celdapro/data/models/lote.dart';

void main() {
  group('Lote', () {
    test('sobrevive a toMap/fromMap', () {
      final lote = Lote(
        codigo: 'L-2026-09-A',
        proveedor: 'Proveedor X',
        origen: 'Importado',
        fechaRecepcion: DateTime(2026, 9, 17),
        notas: 'lote de prueba',
      );
      final restored = Lote.fromMap(lote.toMap());
      expect(restored.codigo, 'L-2026-09-A');
      expect(restored.proveedor, 'Proveedor X');
      expect(restored.fechaRecepcion, DateTime(2026, 9, 17));
    });

    test('tolera mapas incompletos', () {
      final restored = Lote.fromMap(const {'id': 3});
      expect(restored.id, 3);
      expect(restored.codigo, '');
      expect(restored.fechaRecepcion.millisecondsSinceEpoch, 0);
    });
  });

  group('Celda', () {
    test('sobrevive a toMap/fromMap con todos los campos', () {
      final celda = Celda(
        id: 7,
        loteId: 2,
        codigoInterno: 'C-001',
        qr: 'QR-ABC',
        marca: 'Samsung',
        modelo: 'INR18650-25R',
        quimica: Chemistry.liIon,
        capacidadNominalMah: 2500,
        voltajeNominal: 3.6,
        fechaFabricacion: DateTime(2025, 1, 10),
        estado: CellState.classified,
        veredicto: Verdict.a,
        sohPct: 94.2,
        ubicacion: 'Estante A1',
        notas: 'ok',
        createdAt: DateTime(2026, 9, 17),
      );
      final r = Celda.fromMap(celda.toMap());
      expect(r.id, 7);
      expect(r.loteId, 2);
      expect(r.codigoInterno, 'C-001');
      expect(r.quimica, Chemistry.liIon);
      expect(r.capacidadNominalMah, 2500);
      expect(r.estado, CellState.classified);
      expect(r.veredicto, Verdict.a);
      expect(r.sohPct, 94.2);
      expect(r.fechaFabricacion, DateTime(2025, 1, 10));
    });

    test('veredicto y fecha nulos se conservan como null', () {
      final celda = Celda(
        codigoInterno: 'C-002',
        createdAt: DateTime(2026, 9, 17),
      );
      final r = Celda.fromMap(celda.toMap());
      expect(r.veredicto, isNull);
      expect(r.fechaFabricacion, isNull);
      expect(r.estado, CellState.received);
    });

    test('copyWith conserva lo no indicado', () {
      final celda = Celda(
        codigoInterno: 'C-003',
        marca: 'LG',
        createdAt: DateTime(2026, 9, 17),
      );
      final c = celda.copyWith(estado: CellState.testing);
      expect(c.codigoInterno, 'C-003');
      expect(c.marca, 'LG');
      expect(c.estado, CellState.testing);
    });

    test('fromName tolera valores desconocidos', () {
      expect(CellState.fromName('inventado'), CellState.received);
      expect(Chemistry.fromName('xyz'), Chemistry.other);
    });
  });

  group('CellTest', () {
    test('sobrevive a toMap/fromMap', () {
      final t = CellTest(
        id: 1,
        celdaId: 7,
        fecha: DateTime(2026, 9, 17, 10, 30),
        voltajeV: 3.85,
        capacidadMedidaMah: 2350,
        resistenciaInternaMohm: 22.5,
        ciclos: 120,
        corrienteDescargaA: 1.0,
        temperaturaC: 25.4,
        sohPct: 94.0,
        veredicto: Verdict.a,
        operador: 'Steve',
        notas: 'ok',
      );
      final r = CellTest.fromMap(t.toMap());
      expect(r.celdaId, 7);
      expect(r.capacidadMedidaMah, 2350);
      expect(r.resistenciaInternaMohm, 22.5);
      expect(r.ciclos, 120);
      expect(r.veredicto, Verdict.a);
      expect(r.fecha, DateTime(2026, 9, 17, 10, 30));
    });

    test('campos opcionales nulos', () {
      final t = CellTest(celdaId: 1, fecha: DateTime(2026, 1, 1));
      final r = CellTest.fromMap(t.toMap());
      expect(r.capacidadMedidaMah, isNull);
      expect(r.veredicto, isNull);
      expect(r.operador, isNull);
    });
  });

  group('CellEvent', () {
    test('sobrevive a toMap/fromMap', () {
      final e = CellEvent(
        celdaId: 4,
        tipo: EventType.stateChanged,
        estadoAnterior: CellState.testing.name,
        estadoNuevo: CellState.classified.name,
        fecha: DateTime(2026, 9, 17, 11),
        nota: 'clasificada como A',
      );
      final r = CellEvent.fromMap(e.toMap());
      expect(r.celdaId, 4);
      expect(r.tipo, EventType.stateChanged);
      expect(r.estadoNuevo, 'classified');
      expect(r.nota, 'clasificada como A');
    });

    test('fromName tolera desconocidos', () {
      expect(EventType.fromName('zzz'), EventType.note);
    });
  });
}
