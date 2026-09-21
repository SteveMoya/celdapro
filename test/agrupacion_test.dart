import 'package:celdapro/core/agrupacion.dart';
import 'package:celdapro/core/classification.dart';
import 'package:celdapro/data/models/celda.dart';
import 'package:celdapro/data/models/cell_test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Celda de prueba con lo mínimo que exige el modelo.
Celda celdaDePrueba({
  String codigo = 'C-0001',
  Chemistry quimica = Chemistry.liIon,
  CellState estado = CellState.classified,
  Verdict? veredicto,
  double? capacidadNominalMah = 2500,
}) =>
    Celda(
      codigoInterno: codigo,
      quimica: quimica,
      estado: estado,
      veredicto: veredicto,
      capacidadNominalMah: capacidadNominalMah,
      createdAt: DateTime(2026, 9, 20),
    );

/// Celda ya medida, lista para agrupar.
CeldaMedida medida({
  String codigo = 'C-0001',
  Chemistry quimica = Chemistry.liIon,
  CellState estado = CellState.classified,
  Verdict? veredicto,
  double? capacidadMah = 2400,
  double? irMohm = 25,
  double? voltajeV = 3.7,
  double? sohPct,
}) =>
    CeldaMedida(
      celda: celdaDePrueba(
        codigo: codigo,
        quimica: quimica,
        estado: estado,
        veredicto: veredicto,
      ),
      capacidadMah: capacidadMah,
      irMohm: irMohm,
      voltajeV: voltajeV,
      sohPct: sohPct ?? 96,
    );

void main() {
  group('ToleranciasAgrupacion', () {
    test('trae los valores por defecto de la app', () {
      const t = ToleranciasAgrupacion();
      expect(t.capacidadPct, 5.0);
      expect(t.irPct, 10.0);
      expect(t.sohPuntos, 5.0);
      expect(t.voltajeV, 0.05);
    });

    test('se guardan y se leen igual', () {
      const t = ToleranciasAgrupacion(
        capacidadPct: 8,
        irPct: 12,
        sohPuntos: 4,
        voltajeV: 0.08,
      );
      expect(ToleranciasAgrupacion.fromMap(t.toMap()), t);
    });

    test('un mapa vacío o con basura cae a los valores por defecto', () {
      expect(ToleranciasAgrupacion.fromMap({}), const ToleranciasAgrupacion());
      expect(ToleranciasAgrupacion.fromMap({'capacidadPct': 'ocho'}),
          const ToleranciasAgrupacion());
    });

    test('sanitized impide tolerancias negativas o absurdas', () {
      const t = ToleranciasAgrupacion(
        capacidadPct: -5,
        irPct: 900,
        sohPuntos: -1,
        voltajeV: 99,
      );
      final s = t.sanitized();
      expect(s.capacidadPct, 0);
      expect(s.irPct, 100);
      expect(s.sohPuntos, 0);
      expect(s.voltajeV, 5);
    });
  });

  group('CeldaMedida.de', () {
    test('toma los datos del último test', () {
      final c = CeldaMedida.de(
        celdaDePrueba(),
        CellTest(
          celdaId: 1,
          fecha: DateTime(2026, 9, 20),
          capacidadMedidaMah: 2200,
          resistenciaInternaMohm: 30,
          voltajeV: 3.6,
          sohPct: 88,
        ),
      );
      expect(c.capacidadMah, 2200);
      expect(c.irMohm, 30);
      expect(c.voltajeV, 3.6);
      expect(c.sohPct, 88);
    });

    test('si el test no trae SoH, lo calcula con la capacidad nominal', () {
      final c = CeldaMedida.de(
        celdaDePrueba(capacidadNominalMah: 2500),
        CellTest(
          celdaId: 1,
          fecha: DateTime(2026, 9, 20),
          capacidadMedidaMah: 2250,
        ),
      );
      expect(c.sohPct, closeTo(90.0, 0.001));
    });

    test('una celda sin test queda sin medición', () {
      final c = CeldaMedida.de(celdaDePrueba(), null);
      expect(c.capacidadMah, isNull);
      expect(c.sohPct, isNull);
    });
  });

  group('Motivo de exclusión', () {
    test('una celda sin test no se agrupa', () {
      final c = CeldaMedida.de(celdaDePrueba(), null);
      expect(motivoPara(c), MotivoExclusion.sinMedicion);
    });

    test('una celda con veredicto de rechazo no se agrupa', () {
      final c = medida(veredicto: Verdict.reject);
      expect(motivoPara(c), MotivoExclusion.rechazada);
    });

    test('una celda descartada no se agrupa', () {
      final c = medida(estado: CellState.rejected);
      expect(motivoPara(c), MotivoExclusion.descartada);
    });

    test('una celda ya empacada no se agrupa (para no sacarla de su pack)', () {
      final c = medida(estado: CellState.repacked);
      expect(motivoPara(c), MotivoExclusion.yaEmpacada);
    });

    test('una celda medida y clasificada sí se agrupa', () {
      expect(motivoPara(medida()), isNull);
    });

    test('el orden de prioridad: descartada gana a sin medición', () {
      // Una celda marcada como descartada y sin medir: se informa lo primero,
      // que es lo que de verdad explica por qué no entra.
      final c = CeldaMedida.de(
        celdaDePrueba(estado: CellState.rejected),
        null,
      );
      expect(motivoPara(c), MotivoExclusion.descartada);
    });
  });

  group('Agrupación básica', () {
    test('celdas parecidas caen en el mismo grupo', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'A', capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'B', capacidadMah: 2380, sohPct: 95),
        medida(codigo: 'C', capacidadMah: 2420, sohPct: 97),
      ]);

      expect(r.gruposDePack, hasLength(1));
      expect(r.gruposDePack.first.tamano, 3);
      expect(r.celdasAgrupadas, 3);
    });

    test('celdas muy distintas no se juntan', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'A', capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'B', capacidadMah: 1500, sohPct: 60),
      ]);

      // Dos grupos de una: no hay pack posible.
      expect(r.gruposDePack, isEmpty);
      expect(r.sinCompania, hasLength(2));
    });

    test('LA GARANTÍA: dentro de un grupo nadie se separa más que la tolerancia',
        () {
      // Este es el test que de verdad importa. Se meten muchas celdas de
      // capacidades y SoH variados y se comprueba que en NINGÚN grupo hay dos
      // celdas que se separen más de lo permitido.
      const tol = ToleranciasAgrupacion();
      final celdas = [
        for (var i = 0; i < 60; i++)
          medida(
            codigo: 'C-${i.toString().padLeft(3, '0')}',
            capacidadMah: 1000.0 + i * 25,
            sohPct: 60.0 + i * 0.6,
            irMohm: 20.0 + i * 0.5,
            voltajeV: 3.5 + i * 0.003,
          ),
      ];

      final r = agruparConMotivos(celdas: celdas, tolerancias: tol);

      for (final g in r.grupos) {
        for (final a in g.celdas) {
          for (final b in g.celdas) {
            final ca = a.capacidadMah!, cb = b.capacidadMah!;
            final mayor = ca > cb ? ca : cb;
            expect((ca - cb).abs() / mayor * 100, lessThanOrEqualTo(tol.capacidadPct + 1e-9),
                reason: 'la capacidad de ${a.codigo} y ${b.codigo} se separa '
                    'más de la tolerancia estando en el mismo grupo');
            expect((a.sohPct! - b.sohPct!).abs(), lessThanOrEqualTo(tol.sohPuntos + 1e-9),
                reason: 'el SoH de ${a.codigo} y ${b.codigo} se separa de más');
            expect((a.irMohm! - b.irMohm!).abs() / (a.irMohm! > b.irMohm! ? a.irMohm! : b.irMohm!) * 100,
                lessThanOrEqualTo(tol.irPct + 1e-9));
            expect((a.voltajeV! - b.voltajeV!).abs(),
                lessThanOrEqualTo(tol.voltajeV + 1e-9));
          }
        }
      }
      // Y todas las celdas entran en algún sitio: no se pierde ninguna.
      expect(r.celdasAgrupadas + r.sinCompania.length, 60);
    });

    test('la poda no se salta celdas que sí encajan', () {
      // Con la poda activa, una celda compatible que va después de una
      // incompatible tiene que seguir entrando en el grupo.
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'A', capacidadMah: 2400, sohPct: 96),
        // Ésta no encaja por SoH aunque la capacidad sí.
        medida(codigo: 'B', capacidadMah: 2350, sohPct: 70),
        // Y ésta tiene que acabar en el grupo de A.
        medida(codigo: 'C', capacidadMah: 2300, sohPct: 95),
      ]);

      final grupoA = r.grupos.firstWhere(
        (g) => g.celdas.any((c) => c.codigo == 'A'),
      );
      expect(grupoA.celdas.map((c) => c.codigo), containsAll(['A', 'C']));
      expect(grupoA.celdas.map((c) => c.codigo), isNot(contains('B')));
    });
  });

  group('Química', () {
    test('una química distinta NUNCA entra en el mismo grupo', () {
      // Mismo todo, salvo la química: no se pueden mezclar jamás.
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'Li', quimica: Chemistry.liIon, capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'LFP', quimica: Chemistry.lfp, capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'LTO', quimica: Chemistry.lto, capacidadMah: 2400, sohPct: 96),
      ]);

      expect(r.gruposDePack, isEmpty,
          reason: 'tres químicas distintas no pueden formar un pack');
      for (final g in r.grupos) {
        final quimicas = g.celdas.map((c) => c.celda.quimica).toSet();
        expect(quimicas, hasLength(1));
      }
    });

    test('agrupa por separado cada química', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'Li1', quimica: Chemistry.liIon, capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'Li2', quimica: Chemistry.liIon, capacidadMah: 2390, sohPct: 95),
        medida(codigo: 'LFP1', quimica: Chemistry.lfp, capacidadMah: 3000, sohPct: 98),
        medida(codigo: 'LFP2', quimica: Chemistry.lfp, capacidadMah: 2980, sohPct: 97),
      ]);

      expect(r.gruposDePack, hasLength(2));
      final quimicas = r.gruposDePack.map((g) => g.quimica).toSet();
      expect(quimicas, hasLength(2));
    });
  });

  group('Los criterios de aceptación del plan', () {
    test('una celda de 62 % de SoH no cae con otras de 95 %', () {
      final r = agruparConMotivos(celdas: [
        for (var i = 0; i < 5; i++)
          medida(codigo: 'Buenas$i', capacidadMah: 2400, sohPct: 95),
        medida(codigo: 'Mala', capacidadMah: 2400, sohPct: 62),
      ]);

      final grupoBuenas = r.gruposDePack.first;
      expect(grupoBuenas.celdas.map((c) => c.codigo), isNot(contains('Mala')));
      expect(r.sinCompania.map((c) => c.codigo), contains('Mala'));
    });

    test('si el taller ensancha la tolerancia de SoH, entonces sí se juntan', () {
      // El operador manda: con 5 puntos no encajan, con 40 sí.
      final celdas = [
        medida(codigo: 'Alta', capacidadMah: 2400, sohPct: 95),
        medida(codigo: 'Baja', capacidadMah: 2400, sohPct: 62),
      ];

      expect(agruparConMotivos(celdas: celdas).gruposDePack, isEmpty);
      expect(
        agruparConMotivos(
          celdas: celdas,
          tolerancias: const ToleranciasAgrupacion(sohPuntos: 40),
        ).gruposDePack,
        hasLength(1),
      );
    });

    test('20 celdas de un lote se reparten de forma coherente', () {
      // 12 buenas y parecidas, 8 claramente peores: tienen que salir dos
      // bloques distintos, no todo mezclado.
      final celdas = [
        for (var i = 0; i < 12; i++)
          medida(
            codigo: 'BUENA-${i.toString().padLeft(2, '0')}',
            capacidadMah: 2400.0 + i,
            sohPct: 95.0 + i * 0.1,
          ),
        for (var i = 0; i < 8; i++)
          medida(
            codigo: 'FLOJA-${i.toString().padLeft(2, '0')}',
            capacidadMah: 1900.0 + i,
            sohPct: 74.0 + i * 0.1,
          ),
      ];

      final r = agruparConMotivos(celdas: celdas);
      expect(r.celdasAgrupadas + r.sinCompania.length, 20);
      expect(r.gruposDePack.length, 2, reason: 'deben salir dos bloques limpios');

      final tamanos = r.gruposDePack.map((g) => g.tamano).toList()..sort();
      expect(tamanos, [8, 12]);

      // Y nadie de un bloque se coló en el otro.
      for (final g in r.gruposDePack) {
        final codigos = g.celdas.map((c) => c.codigo).toList();
        final todasBuenas = codigos.every((c) => c.startsWith('BUENA'));
        final todasFlojas = codigos.every((c) => c.startsWith('FLOJA'));
        expect(todasBuenas || todasFlojas, isTrue,
            reason: 'un grupo mezcló celdas buenas con flojas: $codigos');
      }
    });
  });

  group('Determinismo', () {
    test('el orden de entrada no cambia el resultado', () {
      final base = [
        for (var i = 0; i < 25; i++)
          medida(
            codigo: 'C-${i.toString().padLeft(2, '0')}',
            capacidadMah: 2000.0 + i * 40,
            sohPct: 80.0 + i * 0.5,
          ),
      ];

      String resumen(List<CeldaMedida> entrada) => agruparConMotivos(celdas: entrada)
          .grupos
          .map((g) => g.celdasOrdenadas.map((c) => c.codigo).join(','))
          .join(' | ');

      final directo = resumen(base);
      final alReves = resumen(base.reversed.toList());
      final mezclado = resumen([...base]..shuffle());

      expect(alReves, directo);
      expect(mezclado, directo,
          reason: 'agrupar tiene que dar siempre lo mismo con los mismos datos');
    });
  });

  group('Datos del grupo', () {
    test('calcula medias, dispersión y capacidad aprovechable', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'A', capacidadMah: 2400, sohPct: 97, irMohm: 20, voltajeV: 3.70),
        medida(codigo: 'B', capacidadMah: 2300, sohPct: 93, irMohm: 22, voltajeV: 3.68),
      ]);

      final g = r.gruposDePack.single;
      expect(g.capacidadMediaMah, closeTo(2350, 0.01));
      expect(g.sohMedio, closeTo(95, 0.01));
      expect(g.irMediaMohm, closeTo(21, 0.01));
      expect(g.voltajeMedioV, closeTo(3.69, 0.001));
      expect(g.sohSpreadPuntos, closeTo(4, 0.01));
      // La capacidad del pack la marca la más débil: 2300 × 2, no la media.
      expect(g.capacidadAprovechableMah, closeTo(4600, 0.01));
    });

    test('avisa cuando falta algún dato', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'A', capacidadMah: 2400, sohPct: 96, irMohm: 20, voltajeV: 3.7),
        medida(codigo: 'B', capacidadMah: 2380, sohPct: 95, irMohm: null, voltajeV: null),
      ]);

      final g = r.gruposDePack.single;
      expect(g.avisos.any((a) => a.contains('resistencia interna')), isTrue);
      expect(g.avisos.any((a) => a.contains('voltaje')), isTrue);
    });

    test('el grupo se ordena por capacidad de mayor a menor', () {
      final r = agruparConMotivos(celdas: [
        medida(codigo: 'Chica', capacidadMah: 2300, sohPct: 94),
        medida(codigo: 'Grande', capacidadMah: 2400, sohPct: 96),
        medida(codigo: 'Media', capacidadMah: 2350, sohPct: 95),
      ]);

      expect(
        r.gruposDePack.single.celdasOrdenadas.map((c) => c.codigo),
        ['Grande', 'Media', 'Chica'],
      );
    });

    test('un grupo sin datos opcionales no revienta al calcular', () {
      final r = agruparConMotivos(celdas: [
        CeldaMedida(
          celda: celdaDePrueba(codigo: 'A'),
          capacidadMah: 2400,
          sohPct: 96,
        ),
        CeldaMedida(
          celda: celdaDePrueba(codigo: 'B'),
          capacidadMah: 2390,
          sohPct: 95,
        ),
      ]);

      final g = r.gruposDePack.single;
      expect(g.irMediaMohm, isNull);
      expect(g.voltajeMedioV, isNull);
      expect(g.capacidadSpreadPct, isNotNull);
    });
  });

  group('Rendimiento', () {
    test('5 000 celdas se agrupan rápido', () {
      // La poda por capacidad es lo que hace esto posible: si se comparara
      // cada celda contra todas, serían millones de comparaciones.
      final celdas = [
        for (var i = 0; i < 5000; i++)
          medida(
            codigo: 'C-${i.toString().padLeft(5, '0')}',
            capacidadMah: 1500.0 + (i % 100) * 12,
            sohPct: 70.0 + (i % 100) * 0.3,
            irMohm: 20.0 + (i % 50),
            voltajeV: 3.5 + (i % 40) * 0.005,
          ),
      ];

      final cronometro = Stopwatch()..start();
      final r = agruparConMotivos(celdas: celdas);
      cronometro.stop();

      expect(r.celdasAgrupadas + r.sinCompania.length, 5000);
      expect(cronometro.elapsedMilliseconds, lessThan(3000),
          reason: 'agrupar 5 000 celdas tardó '
              '${cronometro.elapsedMilliseconds} ms');
    });
  });
}
