import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

import '../data/database_helper.dart';
import 'photo_service.dart';

/// Datos que declara un archivo de respaldo, sin llegar a restaurarlo.
class BackupInfo {
  const BackupInfo({
    required this.version,
    required this.fecha,
    required this.celdas,
    required this.lotes,
    required this.tests,
    required this.eventos,
    required this.fotos,
    required this.bytes,
  });

  final String version;
  final DateTime fecha;
  final int celdas;
  final int lotes;
  final int tests;
  final int eventos;
  final int fotos;
  final int bytes;

  String get resumen =>
      '$celdas celdas · $lotes lotes · $tests tests · $fotos fotos';
}

/// Error de un respaldo ilegible o de otra aplicación.
class BackupInvalido implements Exception {
  const BackupInvalido(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Resultado de restaurar un respaldo.
class RestoreResult {
  const RestoreResult({required this.info, required this.copiaPrevia});

  final BackupInfo info;

  /// Ruta de la copia de seguridad que se hizo del estado actual antes de
  /// restaurar, por si el archivo elegido no era el que se quería.
  final String copiaPrevia;
}

/// Respaldo y restauración completos: base de datos + fotos + ajustes.
///
/// La app guarda todo en el teléfono; si el teléfono se pierde, se estropea o
/// se desinstala la app, sin un respaldo se pierde el historial del taller.
/// Este servicio empaqueta todo en un solo archivo `.celdapro`.
class BackupService {
  BackupService({DatabaseHelper? db, PhotoService? photos})
      : _db = db ?? DatabaseHelper.instance,
        _photos = photos ?? const PhotoService();

  final DatabaseHelper _db;
  final PhotoService _photos;

  static const _archivoDb = 'celdapro.db';
  static const _archivoManifest = 'manifest.json';
  static const _carpetaFotos = 'fotos';
  static const _app = 'CeldaPro';
  static const _formato = 1;

  /// Crea el respaldo y devuelve el contenido del archivo.
  ///
  /// Cierra la base de datos un instante para copiar el archivo con seguridad
  /// (copiar un SQLite abierto puede dar un archivo a medias) y la reabre.
  Future<Uint8List> crear({String? versionApp, String? nombreTaller}) async {
    final dbPath = await DatabaseHelper.ruta();

    Map<String, int> conteos = const {};
    Uint8List? bytesDb;
    try {
      conteos = await _db.contar();
    } catch (_) {
      conteos = const {};
    }

    await _db.cerrar();
    try {
      final f = File(dbPath);
      if (await f.exists()) bytesDb = await f.readAsBytes();
    } finally {
      await _db.reabrir();
    }

    if (bytesDb == null) {
      throw const BackupInvalido(
        'No se encontró la base de datos. Abre la app una vez y vuelve a '
        'intentarlo.',
      );
    }

    final fotos = <String, Uint8List>{};
    final dir = await _photos.directorio();
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) {
          fotos[p.basename(e.path)] = await e.readAsBytes();
        }
      }
    }

    final manifest = <String, Object?>{
      'app': _app,
      'formato': _formato,
      'version': versionApp ?? 'desconocida',
      'fecha': DateTime.now().toIso8601String(),
      'taller': nombreTaller,
      'celdas': conteos['celdas'] ?? 0,
      'lotes': conteos['lotes'] ?? 0,
      'tests': conteos['tests'] ?? 0,
      'eventos': conteos['eventos'] ?? 0,
      'fotos': fotos.length,
    };

    final archive = Archive()
      ..addFile(ArchiveFile.string(_archivoManifest,
          const JsonEncoder.withIndent('  ').convert(manifest)))
      ..addFile(ArchiveFile.bytes(_archivoDb, bytesDb));
    for (final entry in fotos.entries) {
      archive.addFile(ArchiveFile.bytes(
        '$_carpetaFotos/${entry.key}',
        entry.value,
      ));
    }

    final zipped = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipped);
  }

  /// Lee la cabecera de un respaldo sin tocar los datos actuales.
  BackupInfo inspeccionar(Uint8List bytes) {
    final archive = _abrir(bytes);
    final manifest = _manifest(archive);

    return BackupInfo(
      version: '${manifest['version'] ?? 'desconocida'}',
      fecha: DateTime.tryParse('${manifest['fecha'] ?? ''}') ?? DateTime.now(),
      celdas: _entero(manifest['celdas']),
      lotes: _entero(manifest['lotes']),
      tests: _entero(manifest['tests']),
      eventos: _entero(manifest['eventos']),
      fotos: _entero(manifest['fotos']),
      bytes: bytes.length,
    );
  }

  /// Reemplaza los datos actuales por los del respaldo.
  ///
  /// Antes de tocar nada guarda una copia del estado actual, para que
  /// equivocarse de archivo no sea irreversible.
  Future<RestoreResult> restaurar(Uint8List bytes) async {
    final archive = _abrir(bytes);
    final info = inspeccionar(bytes);

    final dbNueva = _buscar(archive, _archivoDb);
    if (dbNueva == null) {
      throw const BackupInvalido(
        'El archivo no contiene una base de datos de CeldaPro.',
      );
    }

    final dbPath = await DatabaseHelper.ruta();

    // 1. Copia del estado actual.
    await _db.cerrar();
    var copia = '';
    try {
      final actual = File(dbPath);
      if (await actual.exists()) {
        copia = p.join(
          p.dirname(dbPath),
          'celdapro-antes-de-restaurar-'
              '${DateTime.now().millisecondsSinceEpoch}.db',
        );
        await actual.copy(copia);
      }

      // 2. Escribir la base de datos del respaldo.
      await File(dbPath).writeAsBytes(dbNueva.content, flush: true);
    } finally {
      await _db.reabrir();
    }

    // 3. Fotos: se dejan exactamente las del respaldo.
    final dir = await _photos.directorio();
    if (await dir.exists()) {
      await for (final e in dir.list()) {
        if (e is File) await e.delete();
      }
    } else {
      await dir.create(recursive: true);
    }
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (!f.name.startsWith('$_carpetaFotos/')) continue;
      final nombre = p.basename(f.name);
      if (nombre.isEmpty) continue;
      await File(p.join(dir.path, nombre))
          .writeAsBytes(f.content, flush: true);
    }

    return RestoreResult(info: info, copiaPrevia: copia);
  }

  /// Borra las copias de seguridad previas a una restauración.
  Future<int> limpiarCopiasPrevias() async {
    final dbPath = await DatabaseHelper.ruta();
    final dir = Directory(p.dirname(dbPath));
    var borradas = 0;
    if (!await dir.exists()) return 0;
    await for (final e in dir.list()) {
      if (e is File &&
          p.basename(e.path).startsWith('celdapro-antes-de-restaurar-')) {
        await e.delete();
        borradas++;
      }
    }
    return borradas;
  }

  /// Nombre sugerido para el archivo de respaldo.
  static String nombreArchivo([DateTime? fecha]) {
    final f = fecha ?? DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    return 'CeldaPro-respaldo-${f.year}${dos(f.month)}${dos(f.day)}-'
        '${dos(f.hour)}${dos(f.minute)}.celdapro';
  }

  // ---------- Interno ----------

  Archive _abrir(Uint8List bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const BackupInvalido(
        'El archivo está dañado o no es un respaldo de CeldaPro.',
      );
    }
  }

  ArchiveFile? _buscar(Archive archive, String nombre) {
    for (final f in archive.files) {
      if (f.isFile && p.basename(f.name) == nombre) return f;
    }
    return null;
  }

  Map<String, Object?> _manifest(Archive archive) {
    final f = _buscar(archive, _archivoManifest);
    if (f == null) {
      throw const BackupInvalido(
        'El archivo no parece un respaldo de CeldaPro (falta la ficha).',
      );
    }
    try {
      final json = jsonDecode(utf8.decode(f.content));
      if (json is! Map) throw const FormatException();
      return json.cast<String, Object?>();
    } catch (_) {
      throw const BackupInvalido('La ficha del respaldo está dañada.');
    }
  }

  int _entero(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
