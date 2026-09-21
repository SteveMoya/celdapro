import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Captura y almacenamiento local de fotos de evidencia.
class PhotoService {
  const PhotoService();

  /// Elige una foto (cámara o galería) y la copia al almacenamiento de la app.
  ///
  /// Devuelve la ruta local definitiva, o null si el usuario canceló.
  Future<String?> pickAndSave({
    required int celdaId,
    bool fromCamera = false,
  }) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return null;

    final dir = await _photosDir();
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path).toLowerCase();
    final dest = p.join(
      dir.path,
      'celda_${celdaId}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(dest);
    return dest;
  }

  Future<Directory> _photosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'fotos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Carpeta donde viven las fotos de evidencia (para respaldos).
  Future<Directory> directorio() => _photosDir();

  /// Elige el logo del taller (versión Pro) y lo copia al almacenamiento.
  ///
  /// Va en su propia carpeta `marca/` para no mezclarlo con las fotos de las
  /// celdas: el respaldo las trata distinto y la galería no debe listarlo.
  Future<String?> pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final dir = await _marcaDir();
    final ext = p.extension(picked.path).isEmpty
        ? '.png'
        : p.extension(picked.path).toLowerCase();
    final dest = p.join(
      dir.path,
      'logo_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(picked.path).copy(dest);
    return dest;
  }

  Future<Directory> _marcaDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'marca'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Carpeta de la marca del taller (para respaldos).
  Future<Directory> directorioMarca() => _marcaDir();

  /// Borra la foto de una celda si existe (al eliminar o reemplazar).
  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // Sin consecuencias: la foto huérfana no rompe nada.
    }
  }

  Future<bool> exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    return File(path).exists();
  }
}
