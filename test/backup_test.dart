import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:celdapro/services/backup_service.dart';

/// Construye un respaldo como los que produce la app, para poder comprobar la
/// lectura sin depender del teléfono.
Uint8List respaldoFalso({
  Map<String, Object?>? manifest,
  bool incluirDb = true,
  Map<String, List<int>> fotos = const {},
}) {
  final archive = Archive();
  archive.addFile(ArchiveFile.string(
    'manifest.json',
    jsonEncode(manifest ??
        {
          'app': 'CeldaPro',
          'formato': 1,
          'version': '0.3.0',
          'fecha': '2026-09-20T10:00:00.000',
          'celdas': 42,
          'lotes': 3,
          'tests': 61,
          'eventos': 103,
          'fotos': 7,
        }),
  ));
  if (incluirDb) {
    archive.addFile(ArchiveFile.bytes(
      'celdapro.db',
      List<int>.generate(2048, (i) => i % 251),
    ));
  }
  for (final f in fotos.entries) {
    archive.addFile(ArchiveFile.bytes('fotos/${f.key}', f.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}

void main() {
  final service = BackupService();

  group('Inspeccionar un respaldo', () {
    test('lee la ficha y los conteos', () {
      final info = service.inspeccionar(respaldoFalso());

      expect(info.version, '0.3.0');
      expect(info.fecha.year, 2026);
      expect(info.fecha.month, 9);
      expect(info.celdas, 42);
      expect(info.lotes, 3);
      expect(info.tests, 61);
      expect(info.eventos, 103);
      expect(info.fotos, 7);
      expect(info.bytes, greaterThan(0));
    });

    test('el resumen es legible', () {
      final info = service.inspeccionar(respaldoFalso());
      expect(info.resumen, '42 celdas · 3 lotes · 61 tests · 7 fotos');
    });

    test('cuenta las fotos incluidas si la ficha no las trae', () {
      final info = service.inspeccionar(respaldoFalso(
        manifest: {
          'app': 'CeldaPro',
          'formato': 1,
          'version': '0.3.0',
          'fecha': '2026-09-20T10:00:00.000',
        },
      ));
      expect(info.celdas, 0);
      expect(info.version, '0.3.0');
    });

    test('un archivo que no es zip se rechaza con un mensaje claro', () {
      expect(
        () => service.inspeccionar(Uint8List.fromList(List.filled(200, 7))),
        throwsA(isA<BackupInvalido>()),
      );
    });

    test('un zip sin ficha se rechaza', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('otra-cosa.txt', 'hola'));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(
        () => service.inspeccionar(bytes),
        throwsA(isA<BackupInvalido>()),
      );
    });

    test('una ficha corrupta se rechaza', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', '{no es json}'))
        ..addFile(ArchiveFile.bytes('celdapro.db', [1, 2, 3]));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));

      expect(() => service.inspeccionar(bytes),
          throwsA(isA<BackupInvalido>()));
    });

    test('un zip válido pero de otra app no se confunde', () {
      final archive = Archive()
        ..addFile(ArchiveFile.string('manifest.json', '{"app":"Otra"}'));
      final bytes = Uint8List.fromList(ZipEncoder().encode(archive));
      // Se puede leer, pero no trae base de datos: restaurarlo debe fallar.
      final info = service.inspeccionar(bytes);
      expect(info.celdas, 0);
    });
  });

  group('Nombre del archivo de respaldo', () {
    test('incluye fecha y hora, y la extensión propia', () {
      final nombre = BackupService.nombreArchivo(DateTime(2026, 9, 20, 14, 5));
      expect(nombre, 'CeldaPro-respaldo-20260920-1405.celdapro');
    });

    test('rellena con ceros a la izquierda', () {
      final nombre = BackupService.nombreArchivo(DateTime(2026, 1, 2, 3, 4));
      expect(nombre, 'CeldaPro-respaldo-20260102-0304.celdapro');
    });
  });

  group('Respaldo íntegro', () {
    test('el zip conserva la base de datos y las fotos tal cual', () {
      final original = respaldoFalso(
        fotos: {
          'celda_1_1.jpg': [1, 2, 3, 4],
          'celda_2_9.jpg': [9, 8, 7],
        },
        manifest: {
          'app': 'CeldaPro',
          'formato': 1,
          'version': '0.3.0',
          'fecha': '2026-09-20T10:00:00.000',
          'celdas': 2,
          'lotes': 1,
          'tests': 2,
          'eventos': 4,
          'fotos': 2,
        },
      );

      final info = service.inspeccionar(original);
      expect(info.fotos, 2);

      final archive = ZipDecoder().decodeBytes(original);
      final nombres = archive.files.map((f) => f.name).toList();
      expect(nombres, contains('celdapro.db'));
      expect(nombres, contains('manifest.json'));
      expect(nombres, contains('fotos/celda_1_1.jpg'));

      final foto = archive.files
          .firstWhere((f) => f.name == 'fotos/celda_1_1.jpg');
      expect(foto.content, [1, 2, 3, 4]);
    });
  });
}
